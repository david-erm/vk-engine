const std = @import("std");
const Io = std.Io;

const vk = @import("vk");
const gltf = @import("zgltf").Gltf;
const sdl = @import("sdl.zig");
const vma = @import("vma.zig");
const ktx = @import("ktx.zig");
const math = @import("math.zig");

pub const Vec3 = math.Vec3;
pub const Quat = math.Quat;
pub const Pose = math.Pose;

const log = std.log.scoped(.howtovulkan);

pub fn makeError(err: type, ret: anytype) err!void {
    switch (ret) {
        @fromBackingInt(@intCast(0)) => {
            return;
        },
        inline else => |t| {
            return @field(err, @tagName(t));
        },
    }
}

pub const Camera = struct {
    const pitch_limit = std.math.pi / 2.0 - 0.1;

    pose: Pose = .{ .extra = 0 },
    sens: f32 = 0.002,
    movespeed: f32 = 10,
    fov: f32 = std.math.pi / 3.0,

    pub fn mouseInput(cam: *Camera, relative_x: f32, relative_y: f32) void {
        const old_pitch = cam.pose.extra;
        const f = cam.sens;

        cam.pose.extra += relative_y * f;
        if (@abs(cam.pose.extra) > pitch_limit) {
            const diff = @as(f32, std.math.sign(old_pitch)) * pitch_limit - old_pitch;
            cam.pose.rot = cam.pose.rot.mul(.fromAngleAxis(diff, .{ .x = 1 }));
            cam.pose.extra = old_pitch + diff;
        } else cam.pose.rot = cam.pose.rot.mul(.fromAngleAxis(relative_y * f, .{ .x = 1 }));

        cam.pose.rot = Quat.mul(.fromAngleAxis(-relative_x * f, .{ .y = 1 }), cam.pose.rot);
        cam.pose.rot = cam.pose.rot.normalize();
    }

    pub fn moveInput(cam: *Camera, dT: f32, in: [4]bool) void {
        var axis: Vec3 = .{};
        const lookup: [4]Vec3 = .{
            Vec3{ .z = -1 },
            Vec3{ .z = 1 },
            Vec3{ .x = 1 },
            Vec3{ .x = -1 },
        };

        for (lookup, in) |v, dir| {
            if (dir) {
                axis = axis.add(v);
            }
        }

        axis = axis.normalize();

        cam.pose.pos = Vec3.add(cam.pose.pos, .rotate(axis.scale(dT * cam.movespeed), cam.pose.rot));
    }
};
