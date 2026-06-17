const std = @import("std");

//TODO: pls gen Vector types
// maybe just cope with no member functions and have free functions instead
pub const Vec4 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 0,

    pub fn xyz(v: Vec4) Vec3 {
        return .{ .x = v.x, .y = v.y, .z = v.z };
    }

    pub fn vec4(v: Vec3, w: f32) Vec4 {
        return .{ .x = v.x, .y = v.y, .z = v.z, .w = w };
    }
};

pub fn Vec(T: type, len: u32) type {
    const field_names: []const []const u8 = &.{ "x", "y", "z", "w" };
    return @Struct(.@"extern", null, field_names[0..len], &@splat(T), &@splat(.{}));
}

test {
    const v1: Vec(f32, 3) = .{ .x = 1.0, .y = 2.0, .z = 2.0 };
    const v2: Vec(f32, 3) = .{ .x = -1.0, .y = -2.0, .z = -2.0 };
    const v3 = v1.add(v2);
    std.debug.print("{}", .{v3});
}

pub const Vec2 = extern struct { x: f32 = 0, y: f32 = 0 };
pub const IVec2 = extern struct { x: i32 = 0, y: i32 = 0 };
pub const UVec2 = extern struct { x: u32 = 0, y: u32 = 0 };
// pub const Vertex = extern struct { pos: Vec3, norm: Vec3, uv: Vec2 };
pub const Mat4 = extern struct {
    data: [4][4]f32,

    pub const indentity: Mat4 = .{ .data = .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    } };

    pub const zero: Mat4 = .{ .data = .{
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    } };

    //RH_ZO
    pub fn perspective(angle: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const tanHalfFovy = @tan(angle / 2.0);

        var result: Mat4 = .zero;

        result.data[0][0] = 1.0 / (aspect * tanHalfFovy);
        result.data[1][1] = 1.0 / tanHalfFovy;
        result.data[2][2] = far / (near - far);
        result.data[2][3] = -1.0;
        result.data[3][2] = -(far * near) / (far - near);
        return result;
    }

    //RH_ZO
    pub fn ortho(left: f32, right: f32, bottom: f32, top: f32) Mat4 {
        var result: Mat4 = .indentity;
        result.data[0][0] = 2 / (right - left);
        result.data[1][1] = 2 / (top - bottom);
        result.data[2][2] = -1;
        result.data[3][0] = -(right + left) / (right - left);
        result.data[3][1] = -(top + bottom) / (top - bottom);
        return result;
    }

    pub fn translate(self: Mat4, vec: Vec3) Mat4 {
        var ret = self;
        ret.data[3][0] = vec.x;
        ret.data[3][1] = vec.y;
        ret.data[3][2] = vec.z;
        return ret;
    }
};

pub const Vec3 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn rotate(v: Vec3, q: Quat) Vec3 {
        const vq: Quat = .{ .x = v.x, .y = v.y, .z = v.z, .r = 0 };
        const result = q.mul(vq).mul(q.conjugate());
        return .{ .x = result.x, .y = result.y, .z = result.z };
    }

    pub fn add(v1: Vec3, v2: Vec3) Vec3 {
        return .{ .x = v1.x + v2.x, .y = v1.y + v2.y, .z = v1.z + v2.z };
    }

    pub fn mul(v1: Vec3, v2: Vec3) Vec3 {
        return .{ .x = v1.x * v2.x, .y = v1.y * v2.y, .z = v1.z * v2.z };
    }

    pub fn scale(v: Vec3, factor: f32) Vec3 {
        return .{ .x = v.x * factor, .y = v.y * factor, .z = v.z * factor };
    }

    pub fn norm(v: Vec3) f32 {
        return @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    }

    pub fn normalize(v: Vec3) Vec3 {
        const mag = v.norm();
        if (mag > 0) {
            return .{ .x = v.x / mag, .y = v.y / mag, .z = v.z / mag };
        } else return .{};
    }
};
pub const Quat = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    r: f32 = 0,

    pub const identity: Quat = .{ .r = 1 };

    pub fn fromAngleAxis(theta: f32, axis: Vec3) Quat {
        const s = @sin(theta / 2);
        return .{ .r = @cos(theta / 2), .x = axis.x * s, .y = axis.y * s, .z = axis.z * s };
    }

    pub fn scale(q1: Quat, a: f32) Quat {
        return .{ .x = q1.x * a, .y = q1.y * a, .z = q1.z * a, .r = q1.r * a };
    }

    pub fn norm(q1: Quat) f32 {
        return @sqrt(q1.r * q1.r + q1.x * q1.x + q1.y * q1.y + q1.z * q1.z);
    }

    pub fn normalize(q1: Quat) Quat {
        return q1.scale(1 / q1.norm());
    }

    pub fn conjugate(q1: Quat) Quat {
        return .{ .x = -q1.x, .y = -q1.y, .z = -q1.z, .r = q1.r };
    }

    pub fn mul(q1: Quat, q2: Quat) Quat {
        return .{
            .x = q1.r * q2.x + q2.r * q1.x + q1.y * q2.z - q1.z * q2.y,
            .y = q1.r * q2.y + q2.r * q1.y + q1.z * q2.x - q1.x * q2.z,
            .z = q1.r * q2.z + q2.r * q1.z + q1.x * q2.y - q1.y * q2.x,
            .r = q1.r * q2.r - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z,
        };
    }
};

pub const Pose = extern struct {
    pos: Vec3 = .{},
    extra: f32 = 1,
    rot: Quat = .identity,
};

test "sanity check" {
    const q1: Quat = .fromAngleAxis(std.math.pi / 2.0, .{ .x = 1 });
    const q2: Quat = .fromAngleAxis(std.math.pi / 4.0, .{ .y = 1 });
    const q3 = q2.mul(q1);

    const v: Vec3 = .{ .x = 1 };
    const v2 = v.rotate(q3);
    _ = v2;
}
