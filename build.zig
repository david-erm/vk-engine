const std = @import("std");
const log = std.log.scoped(.build);

pub fn build(b: *std.Build) void {
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

    const spirv = compileShader(b, "src/shaders/shader.slang");

    const exe = b.addExecutable(.{
        .name = "howtovulkan",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c", .module = cMod },
                .{ .name = "shader", .module = spirv },
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
    const slangc_run = b.addSystemCommand(&.{"slangc"});
    slangc_run.addFileArg(b.path(file));
    slangc_run.addArgs(&.{ "-matrix-layout-column-major", "-target", "spirv", "-o" });
    const path = slangc_run.addOutputFileArg(std.fs.path.stem(file));
    return b.createModule(.{ .root_source_file = path });
}
