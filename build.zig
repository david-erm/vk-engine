const std = @import("std");
const log = std.log.scoped(.build);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_sdk = b.graph.environ_map.get("VULKAN_SDK") orelse {
        log.err("Could not find VulkanSDK. Try sourcing setup-env.sh", .{});
        return;
    };
    log.info("VulkanSDK at: {s}", .{vulkan_sdk});
    const vulkan_include = b.fmt("{s}/include", .{vulkan_sdk});

    const c = b.addTranslateC(.{
        .root_source_file = b.addWriteFiles().add("c.h",
            \\#include "tinyobj_loader_c.h"
        ),
        .target = target,
        .optimize = optimize,
    });
    c.addIncludePath(.{ .cwd_relative = vulkan_include });
    c.addIncludePath(b.path("src/include"));

    const cMod = c.createModule();
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
    cMod.link_libcpp = true;
    cMod.addIncludePath(.{ .cwd_relative = vulkan_include });
    cMod.addIncludePath(b.path("src/include"));
    cMod.linkSystemLibrary("SDL3", .{});
    cMod.linkSystemLibrary("ktx", .{});

    const vk = b.createModule(.{
        .root_source_file = b.path("src/vk.zig"),
        .target = target,
        .optimize = optimize,
    });

    const shaders = try compileShaders(b, vk, target, optimize, &.{
        "src/shaders/shader.slang",
        "src/shaders/skybox.slang",
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
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
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
        }),
    });
    // const reflect_gen_step = b.addRunArtifact(reflect_gen);

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

        slangc.addArg("-reflection-json");
        const json = slangc.addOutputFileArg(b.fmt("{s}.json", .{filename}));
        codegen_step.addFileArg(json);

        slangc.addFileArg(b.path(path));
        slangc.addArgs(&.{ "-matrix-layout-column-major", "-target", "spirv", "-o" });
        const spirv = slangc.addOutputFileArg(filename);

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
