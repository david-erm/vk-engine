const std = @import("std");
const Io = std.Io;
const Build = std.Build;
const log = std.log.scoped(.build);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const bake_optimize = b.option(std.builtin.OptimizeMode, "bake-optimize", "Optimization level for bake step binaries") orelse .ReleaseFast;

    const vulkan_sdk = b.graph.environ_map.get("VULKAN_SDK") orelse {
        log.err("Could not find VulkanSDK. Try sourcing setup-env.sh", .{});
        return;
    };
    log.info("VulkanSDK at: {s}", .{vulkan_sdk});

    //vulkan binds
    const instance_extensions: []const [:0]const u8 = &.{
        "VK_KHR_surface",
        "VK_EXT_debug_utils",
    };
    const device_extensions: []const [:0]const u8 = &.{
        "VK_KHR_swapchain",
    };
    const python_path = b.findProgramLazy(.{ .names = &.{ "python", "python3" } });
    const python = b.addRunFile(python_path);
    python.addFileArg(b.path("tools/binds.py"));
    python.addArg("--version=1.3");
    python.addArg("--instance_extensions");
    python.addArgs(instance_extensions);
    python.addArg("--device_extensions");
    python.addArgs(device_extensions);
    const vk_binds = python.addPrefixedOutputFileArg("--file=", "vk.zig");

    //system includes
    const vulkan = b.graph.cwdRelativePath(b.fmt("{s}/include", .{vulkan_sdk}));
    const freetype = b.graph.cwdRelativePath("/usr/include/freetype2");

    //project include
    const include = b.path("src/include");

    //dependecies
    const zgltf = b.dependency("zgltf", .{});

    //project modules
    const vk = b.createModule(.{
        .root_source_file = vk_binds,
        .target = target,
        .optimize = optimize,
    });

    const ktx = b.createModule(.{
        .root_source_file = b.path("src/ktx.zig"),
        .target = target,
        .optimize = optimize,
    });

    buildBake(b, bake_optimize, ktx);

    const c = b.addTranslateC(.{
        .root_source_file = b.addWriteFiles().add("c.h",
            \\#include "tinyobj_loader_c.h"
            \\#include <ft2build.h>
            \\#define FT_FREETYPE_H
            \\#include <freetype/freetype.h>
        ),
        .target = target,
        .optimize = optimize,
    });
    c.addIncludePath(include);
    c.addSystemIncludePath(freetype);
    c.linkSystemLibrary("freetype", .{});

    const cMod = c.createModule();
    cMod.link_libcpp = true;
    cMod.addCSourceFile(.{
        .file = b.addWriteFiles().add("impl.cpp",
            \\#define VK_NO_PROTOTYPES
            \\#include <vulkan/vulkan.h>
            \\#define VMA_IMPLEMENTATION
            \\#include <vma/vk_mem_alloc.h>
            \\#define TINYOBJ_LOADER_C_IMPLEMENTATION
            \\#include "tinyobj_loader_c.h"
        ),
    });
    cMod.addIncludePath(vulkan);
    cMod.addIncludePath(include);
    cMod.linkSystemLibrary("SDL3", .{});
    cMod.linkSystemLibrary("ktx", .{});

    const shaders = try compileShaders(b, vk, target, optimize, &.{
        "src/shaders/skybox.slang",
        "src/shaders/box.slang",
        "src/shaders/text.slang",
        "src/shaders/pbr.slang",
    });

    const exe = b.addExecutable(.{
        .name = "howtovulkan",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c", .module = cMod },
                .{ .name = "vk", .module = vk },
                .{ .name = "shaders", .module = shaders },
                .{ .name = "zgltf", .module = zgltf.module("zgltf") },
            },
        }),
    });
    const vk_extensions = b.addOptions();
    vk_extensions.addOption([]const [:0]const u8, "instance_extensions", instance_extensions);
    vk_extensions.addOption([]const [:0]const u8, "device_extensions", device_extensions);
    exe.root_module.addOptions("vk_extensions", vk_extensions);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}

pub fn buildBake(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    ktx: *Build.Module,
) void {
    const stb = b.dependency("stb", .{});
    const bc7enc = b.dependency("bc7enc_rdo", .{
        .target = b.graph.host,
        .optimize = optimize,
    });
    const bc7enc_module = bc7enc.module("bc7enc_rdo-zig");

    const c_step = b.addTranslateC(.{
        .root_source_file = b.addWriteFiles().add("c.h",
            \\ #include <stb_image.h>
            \\ #include <assimp/cimport.h>
            \\ #include <assimp/cexport.h>
            \\ #include <assimp/scene.h>
            \\ #include <assimp/postprocess.h>
        ),
        .target = b.graph.host,
        .optimize = optimize,
    });
    c_step.addIncludePath(stb.path(""));
    c_step.linkSystemLibrary("assimp", .{});
    c_step.linkSystemLibrary("ktx", .{});
    const cmod = c_step.createModule();
    cmod.addCSourceFile(.{
        .file = b.addWriteFiles().add("impl.c",
            \\ #define STB_IMAGE_IMPLEMENTATION
            \\ #include <stb_image.h>
        ),
    });
    cmod.addIncludePath(stb.path(""));

    const bake = b.addExecutable(.{
        .name = "bake",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/bake.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });

    bake.root_module.addImport("c", cmod);
    bake.root_module.addImport("ktx", ktx);
    bake.root_module.addImport("bcn", bc7enc_module);
    const bake_step = b.step("bake", "Bake assets");

    const models: []const []const u8 = &.{
        "../zig-graphics/src/assets/glTF-Sample-Assets/Models/DamagedHelmet/glTF/DamagedHelmet.gltf",
        "../zig-graphics/src/assets/glTF-Sample-Assets/Models/Sponza/glTF/Sponza.gltf",
    };

    for (models) |model| {
        const bake_cmd = b.addRunArtifact(bake);
        const model_name = Io.Dir.path.stem(model);

        bake_cmd.addPrefixedFileArg("--model=", b.graph.cwdRelativePath(model));
        const model_dir = bake_cmd.addPrefixedOutputDirectoryArg("--outdir=", model_name);

        const install = b.addInstallDirectory(.{
            .source_dir = model_dir,
            .install_dir = .{ .custom = "assets" },
            .install_subdir = model_name,
        });

        bake_step.dependOn(&bake_cmd.step);
        bake_step.dependOn(&install.step);
    }
}

pub fn compileShaders(
    b: *std.Build,
    vk: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    paths: []const []const u8,
) !*std.Build.Module {
    const reflect_gen = b.addExecutable(.{
        .name = "shader_reflection",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/shader_reflect.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });

    const shaders = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    var shaders_source: std.ArrayList(u8) = .empty;

    for (paths) |path| {
        const codegen_step = b.addRunArtifact(reflect_gen);

        const filename = std.fs.path.stem(path);
        const slangc = b.addSystemCommand(&.{ "slangc", "-Wno-39001", "-depfile" });
        _ = slangc.addDepFileOutputArg(b.fmt("{s}.d", .{filename}));

        slangc.addFileArg(b.path(path));
        slangc.addArgs(&.{ "-matrix-layout-column-major", "-target", "spirv", "-o" });
        const spirv = slangc.addOutputFileArg(b.fmt("{s}.spv", .{filename}));

        slangc.addArg("-reflection-json");
        const json = slangc.addOutputFileArg(b.fmt("{s}.json", .{filename}));
        codegen_step.addFileArg(json);

        // for debuggin
        b.getInstallStep().dependOn(&b.addInstallFileWithDir(json, .{ .custom = "json" }, b.fmt("{s}.json", .{filename})).step);

        const zig = codegen_step.addOutputFileArg(b.fmt("{s}.zig", .{filename}));
        shaders.addAnonymousImport(filename, .{
            .root_source_file = zig,
            .imports = &.{
                .{ .name = "spirv", .module = b.createModule(.{ .root_source_file = spirv }) },
                .{ .name = "vk", .module = vk },
            },
            .target = target,
            .optimize = optimize,
        });

        try shaders_source.appendSlice(b.allocator, b.fmt("pub const {s} = @import(\"{s}\");\n", .{ filename, filename }));
    }

    shaders.root_source_file = b.addWriteFiles().add("shaders.zig", shaders_source.items);

    return shaders;
}
