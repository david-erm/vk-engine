const std = @import("std");
const c = @import("c");
const vk = @import("vk.zig");
const sdl = @import("sdl.zig");
const vma = @import("vma.zig");
const ktx = @import("ktx.zig");

const log = std.log.scoped(.howtovulkan);

pub fn makeError(comptime err: type, ret: anytype) err!void {
    switch (ret) {
        @enumFromInt(0) => {
            return;
        },
        inline else => |t| {
            return @field(err, @tagName(t));
        },
    }
}

//math

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
pub const Vec2 = extern struct { x: f32, y: f32 };
pub const Vertex = extern struct { pos: Vec3, norm: Vec3, uv: Vec2 };
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

test "sanity check" {
    const q1: Quat = .fromAngleAxis(std.math.pi / 2.0, .{ .x = 1 });
    const q2: Quat = .fromAngleAxis(std.math.pi / 4.0, .{ .y = 1 });
    const q3 = q2.mul(q1);

    const v: Vec3 = .{ .x = 1 };
    const v2 = v.rotate(q3);

    std.debug.print("{}\n", .{v2});
}

pub const Camera = extern struct {
    pos: Vec4 = .{},
    rot: Quat = .identity,
};

// pub const Camera = struct {
//     frame: Frame,
//     current_yaw: f32,
// };

pub const ShaderDataBuffer = struct {
    allocInfo: vma.AllocationInfo,
    alloc: vma.Allocation,
    buffer: vk.Buffer,
    address: vk.DeviceAddress,
};

pub const LoadedMesh = struct {
    indices: std.ArrayList(u16),
    vertices: std.ArrayList(Vertex),
};

pub const Texture = struct {
    alon: vma.Allocation,
    image: vk.Image,
    view: vk.ImageView,
    sampler: vk.Sampler,
};

pub fn loadImage(a: std.mem.Allocator, filename: [:0]const u8, device: vk.Device, vka: vma.Allocator, queue: vk.Queue, command_pool: vk.CommandPool) !Texture {
    log.debug("attempting to open: {s}", .{filename});
    var texture: *ktx.Texture = try .fromNamedFile(filename.ptr, .{ .load_image_data_bit = true });
    defer texture.destroy();

    var info: Texture = undefined;
    const format = texture.getVkFormat();

    const image_ci: vk.ImageCreateInfo = .{
        .arrayLayers = texture.numLayers,
        .imageType = @enumFromInt(texture.numDimensions - 1),
        .format = format,
        .extent = .{ .width = texture.baseWidth, .height = texture.baseHeight, .depth = texture.baseDepth },
        .mipLevels = texture.numLevels,
        .samples = .{ .@"1" = true },
        .tiling = .optimal,
        .usage = .{ .transfer_dst = true, .sampled = true },
        .initialLayout = .undefined,
    };
    const alloc_ci: vma.AllocationCreateInfo = .{ .usage = .auto };
    _ = vma.createImage(vka, &image_ci, &alloc_ci, &info.image, &info.alon, null);

    var img_buffer: vk.Buffer = undefined;
    var img_buffer_alloc: vma.Allocation = undefined;
    var img_buffer_alloci: vma.AllocationInfo = undefined;
    const img_buffer_ci: vk.BufferCreateInfo = .{
        .size = texture.dataSize,
        .usage = .{ .transfer_src = true },
    };
    const img_buffer_aci: vma.AllocationCreateInfo = .{ .usage = .auto, .flags = .{ .host_access_sequential_write_bit = true, .mapped_bit = true } };
    _ = vma.createBuffer(vka, &img_buffer_ci, &img_buffer_aci, &img_buffer, &img_buffer_alloc, &img_buffer_alloci);
    defer vma.destroyBuffer(vka, img_buffer, img_buffer_alloc);
    @memcpy(@as([*]u8, @ptrCast(img_buffer_alloci.pMappedData.?)), texture.pData[0..texture.dataSize]);

    const fence_ci: vk.FenceCreateInfo = .{};
    var fence: vk.Fence = undefined;
    try vk.createFence(device, &fence_ci, null, &fence);
    defer vk.destroyFence(device, fence, null);

    var cmd_buf: vk.CommandBuffer = undefined;
    const cmd_buf_ai: vk.CommandBufferAllocateInfo = .{ .commandPool = command_pool, .commandBufferCount = 1, .level = .primary };
    try vk.allocateCommandBuffers(device, &cmd_buf_ai, @ptrCast(&cmd_buf));
    defer vk.freeCommandBuffers(device, command_pool, 1, @ptrCast(&cmd_buf));

    const cmd_binfo: vk.CommandBufferBeginInfo = .{ .flags = .{ .one_time_submit = true } };
    try vk.beginCommandBuffer(cmd_buf, &cmd_binfo);

    const mem_barrier: vk.ImageMemoryBarrier2 = .{
        .dstStageMask = .{ .all_transfer = true },
        .dstAccessMask = .{ .transfer_write = true },
        .oldLayout = .undefined,
        .newLayout = .transfer_dst_optimal,
        .image = info.image,
        .subresourceRange = .{
            .aspectMask = .{ .color = true },
            .levelCount = texture.numLevels,
            .layerCount = texture.numLayers,
        },
    };
    var barrier_texinfo: vk.DependencyInfo = .{
        .imageMemoryBarrierCount = 1,
        .pImageMemoryBarriers = @ptrCast(&mem_barrier),
    };
    vk.cmdPipelineBarrier2(cmd_buf, &barrier_texinfo);

    const copy_regions = try a.alloc(vk.BufferImageCopy, texture.numLevels);
    defer a.free(copy_regions);
    for (0..texture.numLevels) |j| {
        const level: u32 = @intCast(j);
        copy_regions[j] = .{
            .bufferOffset = try texture.getImageOffset(level, 0, 0),
            .imageSubresource = .{
                .aspectMask = .{ .color = true },
                .mipLevel = level,
                .layerCount = texture.numLayers,
            },
            .imageExtent = .{
                .width = texture.baseWidth >> @intCast(j),
                .height = texture.baseHeight >> @intCast(j),
                .depth = texture.baseDepth,
            },
        };
    }
    vk.cmdCopyBufferToImage(cmd_buf, img_buffer, info.image, .transfer_dst_optimal, texture.numLevels, copy_regions.ptr);

    const texread_barrier: vk.ImageMemoryBarrier2 = .{
        .srcStageMask = .{ .all_transfer = true },
        .srcAccessMask = .{ .transfer_write = true },
        .dstStageMask = .{ .fragment_shader = true },
        .dstAccessMask = .{ .shader_read = true },
        .oldLayout = .transfer_dst_optimal,
        .newLayout = .read_only_optimal,
        .image = info.image,
        .subresourceRange = .{
            .aspectMask = .{ .color = true },
            .levelCount = texture.numLevels,
            .layerCount = texture.numLayers,
        },
    };
    barrier_texinfo.pImageMemoryBarriers = @ptrCast(&texread_barrier);
    vk.cmdPipelineBarrier2(cmd_buf, &barrier_texinfo);

    try vk.endCommandBuffer(cmd_buf);
    const sub_info: vk.SubmitInfo = .{
        .commandBufferCount = 1,
        .pCommandBuffers = @ptrCast(&cmd_buf),
    };
    try vk.queueSubmit(queue, 1, @ptrCast(&sub_info), fence);
    try vk.waitForFences(device, 1, @ptrCast(&fence), .True, std.math.maxInt(u64));

    const sampler_ci: vk.SamplerCreateInfo = .{
        .magFilter = .linear,
        .minFilter = .linear,
        .mipmapMode = .linear,
        .anisotropyEnable = .True,
        .maxAnisotropy = 8.0,
        .borderColor = .float_transparent_black,
        .maxLod = @floatFromInt(texture.numLevels),
    };
    try vk.createSampler(device, &sampler_ci, null, &info.sampler);

    const view_ci: vk.ImageViewCreateInfo = .{
        .format = format,
        .image = info.image,
        .viewType = @enumFromInt(texture.numDimensions - 1),
        .subresourceRange = .{
            .layerCount = texture.numLayers,
            .levelCount = texture.numLevels,
            .aspectMask = .{ .color = true },
        },
    };
    try vk.createImageView(device, &view_ci, null, &info.view);

    return info;
}

pub fn loadObj(arena: std.mem.Allocator, io: *std.Io, path: [*:0]const u8) !LoadedMesh {
    var attrib: c.tinyobj_attrib_t = undefined;
    var shapes_num: usize = 0;
    var shapes: ?[*]c.tinyobj_shape_t = null;
    //not doing shi with these
    var materials_num: usize = 0;
    var materials: ?[*]c.tinyobj_material_t = null;
    const ret = c.tinyobj_parse_obj(&attrib, &shapes, &shapes_num, &materials, &materials_num, path, get_file_data, io, c.TINYOBJ_FLAG_TRIANGULATE);
    if (ret != 0) @panic("loading obj failed");

    var vertices: std.ArrayList(Vertex) = .empty;
    var indices: std.ArrayList(u16) = .empty;
    for (0..attrib.num_faces, attrib.faces) |i, face| {
        const v_start: usize = @intCast(face.v_idx * 3);
        const vn_start: usize = @intCast(face.vn_idx * 3);
        const vt_start: usize = @intCast(face.vt_idx * 2);
        const vert: Vertex = .{
            .pos = .{ .x = attrib.vertices[v_start], .y = -attrib.vertices[v_start + 1], .z = attrib.vertices[v_start + 2] },
            .norm = .{ .x = attrib.normals[vn_start], .y = -attrib.normals[vn_start + 1], .z = attrib.normals[vn_start + 2] },
            .uv = .{ .x = attrib.texcoords[vt_start], .y = 1.0 - attrib.texcoords[vt_start + 1] },
        };
        try vertices.append(arena, vert);
        try indices.append(arena, @intCast(i));
    }
    c.tinyobj_attrib_free(&attrib);
    c.tinyobj_materials_free(materials, materials_num);
    c.tinyobj_shapes_free(shapes, shapes_num);

    return .{ .indices = indices, .vertices = vertices };
}

fn get_file_data(ioparam: ?*anyopaque, filename: [*c]const u8, _: i32, _: ?[*]const u8, buf: ?*?[*]u8, len: ?*usize) callconv(.c) void {
    if (filename == null) {
        log.err("bad filename", .{});
        buf.?.* = null;
        len.?.* = 0;
        return;
    }
    const ioreal: *std.Io = @ptrCast(@alignCast(ioparam));
    const io = ioreal.*;

    const cwd = std.Io.Dir.cwd();
    const sfilename = std.mem.span(filename);
    log.debug("attempting to open: {s}", .{sfilename});

    const file = cwd.openFile(io, sfilename, .{ .mode = .read_only }) catch @panic("failed to open file");
    defer file.close(io);

    const stat = file.stat(io) catch @panic("failed to stat file");
    const mmap = file.createMemoryMap(io, .{ .len = stat.size, .protection = .{ .read = true } }) catch @panic("failed to mmap file");
    // defer mmap.destroy(io);
    // TODO: need to make this not just leave the mmpa open

    buf.?.* = mmap.memory.ptr;
    len.?.* = mmap.memory.len;
}
