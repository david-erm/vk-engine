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

    const slang_reflection = b.addExecutable(.{
        .name = "shader_reflection",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/shader_reflect.zig"),
            .target = b.graph.host,
        }),
    });
    const shader_reflect_step = b.addRunArtifact(slang_reflection);
    shader_reflect_step.addFileArg(b.path("test.json"));
    const test_reflect = shader_reflect_step.addOutputFileArg("test.zig");
    const test_module = b.createModule(.{
        .root_source_file = test_reflect,
        .target = target,
        .optimize = optimize,
    });

    const blinn = compileShader(b, "src/shaders/shader.slang");
    const skybox = compileShader(b, "src/shaders/skybox.slang");

    // const shaders = try compileShaders(b, &.{
    //     "src/shaders/shader.slang",
    //     "src/shaders/skybox.slang",
    // });

    const exe = b.addExecutable(.{
        .name = "howtovulkan",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c", .module = cMod },
                .{ .name = "testing", .module = test_module },
                .{ .name = "blinn", .module = blinn },
                .{ .name = "skybox", .module = skybox },
                // .{ .name = "shaders", .module = shaders },
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

pub fn compileShader(b: *std.Build, file: []const u8) *std.Build.Module {
    const filename = std.fs.path.stem(file);
    const slangc = b.addSystemCommand(&.{ "slangc", "-depfile" });
    _ = slangc.addDepFileOutputArg(b.fmt("{s}.d", .{filename}));
    slangc.addFileArg(b.path(file));
    slangc.addArgs(&.{ "-matrix-layout-column-major", "-target", "spirv", "-o" });
    const path = slangc.addOutputFileArg(filename);
    return b.createModule(.{ .root_source_file = path });
}

pub fn compileShaders(b: *std.Build, paths: []const []const u8) !*std.Build.Module {
    const reflect_gen = b.addExecutable(.{
        .name = "shader_reflection",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/shader_reflect.zig"),
            .target = b.graph.host,
        }),
    });
    const reflect_gen_step = b.addRunArtifact(reflect_gen);

    const shaders = b.createModule(.{});
    var shaders_source: std.ArrayList(u8) = .empty;

    for (paths) |path| {
        const filename = std.fs.path.stem(path);
        const slangc = b.addSystemCommand(&.{ "slangc", "-depfile" });
        _ = slangc.addDepFileOutputArg(b.fmt("{s}.d", .{filename}));

        slangc.addArg("-reflection-json");
        const json = slangc.addOutputFileArg(b.fmt("{s}.json", .{filename}));
        reflect_gen_step.addFileArg(json);

        slangc.addFileArg(b.path(path));
        slangc.addArgs(&.{ "-matrix-layout-column-major", "-target", "spirv", "-o" });
        const spirv = slangc.addOutputFileArg(filename);

        const zig = reflect_gen_step.addOutputFileArg(b.fmt("{s}.zig", .{filename}));
        shaders.addAnonymousImport(filename, .{
            .root_source_file = zig,
            .imports = &.{
                .{ .name = "spirv", .module = b.createModule(.{ .root_source_file = spirv }) },
            },
        });
        try shaders_source.appendSlice(b.allocator, b.fmt("const {s} = @import(\"{s}\");\n", .{ filename, filename }));
    }

    shaders.root_source_file = b.addWriteFiles().add("shaders.zig", shaders_source.items);

    return shaders;
}
