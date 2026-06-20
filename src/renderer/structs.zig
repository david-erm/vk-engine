//NOTE: This has to be maintained in sync with src/shaders/structs.slang
//TODO: maybe gen that file from this?
const math = @import("../math.zig");
const vk = @import("vk");

const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
pub const Pose = math.Pose;
const Quat = math.Quat;

pub const Material = extern struct {
    albedo: u32 = 0,
    metallic_roughness: u32 = 0,
    normal: u32 = 0,
    occlusion: u32 = 0,
    emissive: u32 = 0,
};

pub const Vertex = extern struct {
    pos: Vec3,
    norm: Vec3,
    uv: Vec2,
};

//Come up with a new light scheme
pub const Scene = extern struct {
    projection: math.Mat4 = .zero,
    ortho: math.Mat4 = .zero,
    cam: Pose = .{},
    light_pos: math.Vec4 = .{ .x = 0.0, .y = -10.0, .z = 0.0, .w = 0.0 },
    selected: u32 = 1,
};

pub const Push = extern struct {
    scene: vk.DeviceAddress,
    poses: vk.DeviceAddress,
    materials: vk.DeviceAddress,
    vertices: vk.DeviceAddress,
    fif_index: u64,
};

pub const push_range: vk.PushConstantRange = .{
    .offset = 0,
    .size = @sizeOf(Push),
    .stageFlags = .{ .vertex = true },
};
