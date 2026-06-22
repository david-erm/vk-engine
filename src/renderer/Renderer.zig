//TODO: isnt this just a renderer?
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const MemoryPool = std.heap.memory_pool.Extra;

const log = std.log.scoped(.Renderer);

const Gltf = @import("zgltf").Gltf;
pub const c = @import("c");
const vk = @import("vk");

//root
const ktx = @import("../ktx.zig");
const sdl = @import("../sdl.zig");
const vma = @import("../vma.zig");
const zkf = @import("../zkf.zig");
const math = @import("../math.zig");

//render
pub const Context = @import("VkContext.zig").Context;
const st = @import("structs.zig");
const IndexType = u32;

const buffers = @import("buffers.zig");
const Buffer = buffers.Buffer;

const vk_extensions = @import("vk_extensions");

const Renderer = @This();

// LIMITS
pub const max_frames = 2;
pub const max_images = 1000;
pub const max_vertices = 3_000_000;
pub const max_indices = 1_000_000;
//descriptors
pub const max_sampled = 1000;
pub const max_storage = 100;
pub const max_sampler = 1;

pub const ImageHandle = enum(u32) {
    empty = std.math.maxInt(u32),
    _,
};

pub const ImageR = struct {
    handle: vk.Image,
    view: vk.ImageView,
    allocation: vma.Allocation,
};

ctx: Context,
//lazy
cp: vk.CommandPool,
cmdbuf: [max_frames]vk.CommandBuffer,
transfer_cmdbuf: vk.CommandBuffer,

//resources
images: MemoryPool(ImageR, .{ .growable = false }),

desc_man: buffers.DescriptorManager,
graphics_layout: vk.PipelineLayout,

vertices: buffers.GpuMappedPush(st.Vertex),
indices: buffers.GpuMappedPush(IndexType),

//fif?
loop: buffers.TimelineSemaphore,
fif_values: [max_frames]u64,
fif_semaphores: [max_frames]vk.Semaphore,
fif_index: u64,

materials: buffers.GpuMappedPush(st.Material),
poses: buffers.GpuMappedPush(st.Pose),
scene: buffers.GpuMappedPush(st.Scene),

//transfer
upload: buffers.TimelineSemaphore,

pub fn deinit(renderer: *Renderer, gpa: std.mem.Allocator) void {
    renderer.materials.deinit(renderer.ctx.vka);
    renderer.poses.deinit(renderer.ctx.vka);
    renderer.scene.deinit(renderer.ctx.vka);

    for (renderer.fif_semaphores) |smp| {
        vk.destroySemaphore(renderer.ctx.device, smp, null);
    }
    renderer.loop.deinit(renderer.ctx.device);
    renderer.upload.deinit(renderer.ctx.device);

    renderer.vertices.deinit(renderer.ctx.vka);
    renderer.indices.deinit(renderer.ctx.vka);

    vk.destroyPipelineLayout(renderer.ctx.device, renderer.graphics_layout, null);
    renderer.desc_man.deinit(renderer.ctx.device);

    renderer.images.deinit(gpa);

    vk.destroyCommandPool(renderer.ctx.device, renderer.cp, null);
    renderer.ctx.deinit();
    sdl.vulkan.unloadLibrary();
    sdl.quitSubsystem(.{ .video = true });
}

pub fn init(gpa: std.mem.Allocator) !Renderer {
    var out: Renderer = undefined;
    try sdl.init(.{ .video = true });
    try sdl.vulkan.loadLibrary(null);

    var instance_extensions: std.ArrayList([*:0]const u8) = .empty;
    defer instance_extensions.deinit(gpa);
    const sdl_extensions = try sdl.vulkan.getInstanceExtensions();

    try instance_extensions.appendSlice(gpa, sdl_extensions);
    for (vk_extensions.instance_extensions) |ext| {
        try instance_extensions.append(gpa, ext.ptr);
    }

    var device_extensions: std.ArrayList([*:0]const u8) = .empty;
    defer device_extensions.deinit(gpa);
    for (vk_extensions.device_extensions) |ext| {
        try device_extensions.append(gpa, ext.ptr);
    }

    out.ctx = try .init(
        gpa,
        instance_extensions.items,
        device_extensions.items,
        sdl.vulkan.getInstanceProcAddr(),
    );

    try sdl.vulkan.getPresentationSupport(out.ctx.instance, out.ctx.pdevice, out.ctx.qfamily);

    const cp_ci: vk.CommandPoolCreateInfo = .{ .flags = .{ .reset_command_buffer = true }, .queueFamilyIndex = out.ctx.qfamily };
    try vk.createCommandPool(out.ctx.device, &cp_ci, null, &out.cp);
    var cmdbuf_ci: vk.CommandBufferAllocateInfo = .{ .commandPool = out.cp, .commandBufferCount = max_frames, .level = .primary };
    try vk.allocateCommandBuffers(out.ctx.device, &cmdbuf_ci, &out.cmdbuf);
    cmdbuf_ci.commandBufferCount = 1;
    try vk.allocateCommandBuffers(out.ctx.device, &cmdbuf_ci, @ptrCast(&out.transfer_cmdbuf));

    out.desc_man = try .init(out.ctx.device);
    const layout_ci: vk.PipelineLayoutCreateInfo = .{
        .pushConstantRangeCount = 1,
        .pPushConstantRanges = @ptrCast(&st.push_range),
        .setLayoutCount = 1,
        .pSetLayouts = @ptrCast(&out.desc_man.layout),
    };
    try vk.createPipelineLayout(out.ctx.device, &layout_ci, null, &out.graphics_layout);

    out.loop = try .init(out.ctx.device);
    out.fif_values = @splat(0);
    out.fif_index = 0;
    for (out.fif_semaphores, 0..) |_, i| {
        const ci: vk.SemaphoreCreateInfo = .{};
        try vk.createSemaphore(out.ctx.device, &ci, null, &out.fif_semaphores[i]);
    }

    out.materials = try .init(out.ctx.vka, 100, .{ .shader_device_address = true, .storage_buffer = true });
    out.poses = try .init(out.ctx.vka, 100, .{ .shader_device_address = true, .storage_buffer = true });
    out.scene = try .init(out.ctx.vka, 2, .{ .shader_device_address = true, .storage_buffer = true });

    out.vertices = try .init(out.ctx.vka, max_vertices, .{ .shader_device_address = true, .storage_buffer = true });
    try vk.nameHandle(out.ctx.device, out.vertices.handle(), "Vertex Buffer");

    out.indices = try .init(out.ctx.vka, max_indices, .{ .index_buffer = true });
    try vk.nameHandle(out.ctx.device, out.indices.handle(), "Indices Buffer");

    out.images = try .initCapacity(gpa, max_images);

    out.upload = try .init(out.ctx.device);

    return out;
}

pub fn loadTextureFromFile(renderer: *Renderer, gpa: std.mem.Allocator, filename: [:0]const u8) !*ImageR {
    log.debug("attempting to open {q}", .{filename});
    var texture: *ktx.Texture = try .fromNamedFile(filename.ptr, .{ .load_image_data_bit = true });
    defer texture.destroy();
    return loadTexture(renderer, gpa, texture);
}

pub fn loadTextureFromMemory(renderer: *Renderer, gpa: std.mem.Allocator, memory: []const u8) !*ImageR {
    var texture: *ktx.Texture = try .fromMemory(memory, .{ .load_image_data_bit = true });
    defer texture.destroy();
    return loadTexture(renderer, gpa, texture);
}

pub fn loadTexture(renderer: *Renderer, gpa: std.mem.Allocator, texture: *ktx.Texture) !*ImageR {
    const format: vk.Format = @enumFromInt(texture.getVkFormat());

    var image_ci: vk.ImageCreateInfo = .{
        .arrayLayers = texture.numLayers,
        .imageType = @enumFromInt(texture.numDimensions - 1),
        .format = format,
        .extent = .{ .width = texture.baseWidth, .height = texture.baseHeight, .depth = texture.baseDepth },
        .mipLevels = texture.numLevels,
        .samples = .{ .@"1" = true },
        .usage = .{ .transfer_dst = true, .sampled = true, .transfer_src = true },
    };

    if (texture.isCubemap) {
        image_ci.arrayLayers = texture.numFaces;
        image_ci.flags.cube_compatible = true;
    }

    var view_ci: vk.ImageViewCreateInfo = .{
        .format = format,
        .subresourceRange = .{
            .layerCount = image_ci.arrayLayers,
            .levelCount = image_ci.mipLevels,
            .aspectMask = .{ .color = true },
        },
    };
    if (texture.isCubemap) {
        view_ci.viewType = .cube;
    } else view_ci.viewType = .@"2d";

    const image = try renderer.createTexture(&image_ci, &view_ci);
    errdefer renderer.destroyTexture(image);

    //transfer

    const img_buffer: buffers.GpuMapped(u8) = try .init(renderer.ctx.vka, &.{ .size = texture.dataSize, .usage = .{ .transfer_src = true } });
    defer img_buffer.deinit(renderer.ctx.vka);
    @memcpy(img_buffer.data, texture.pData[0..texture.dataSize]);

    const cmd_binfo: vk.CommandBufferBeginInfo = .{ .flags = .{ .one_time_submit = true } };
    try vk.resetCommandBuffer(renderer.transfer_cmdbuf, .{});
    try vk.beginCommandBuffer(renderer.transfer_cmdbuf, &cmd_binfo);

    const mem_barrier: vk.ImageMemoryBarrier2 = .{
        .dstStageMask = .{ .copy = true },
        .dstAccessMask = .{ .transfer_write = true },
        .oldLayout = .undefined,
        .newLayout = .transfer_dst_optimal,
        .image = image.handle,
        .subresourceRange = .{
            .aspectMask = .{ .color = true },
            .levelCount = image_ci.mipLevels,
            .layerCount = image_ci.arrayLayers,
        },
    };
    var barrier_texinfo: vk.DependencyInfo = .{
        .imageMemoryBarrierCount = 1,
        .pImageMemoryBarriers = @ptrCast(&mem_barrier),
    };
    vk.cmdPipelineBarrier2(renderer.transfer_cmdbuf, &barrier_texinfo);

    const copy_regions = try gpa.alloc(vk.BufferImageCopy, texture.numLevels * image_ci.arrayLayers);
    defer gpa.free(copy_regions);
    for (0..image_ci.arrayLayers) |i| {
        const layer: u32 = @intCast(i);
        for (0..texture.numLevels) |j| {
            const level: u32 = @intCast(j);
            copy_regions[i * texture.numLevels + j] = vk.BufferImageCopy{
                .bufferOffset = try texture.getImageOffset(level, 0, layer),
                .imageSubresource = .{
                    .aspectMask = .{ .color = true },
                    .mipLevel = level,
                    .baseArrayLayer = layer,
                    .layerCount = 1,
                },
                .imageExtent = .{
                    .width = texture.baseWidth >> @intCast(j),
                    .height = texture.baseHeight >> @intCast(j),
                    .depth = texture.baseDepth,
                },
            };
        }
    }
    vk.cmdCopyBufferToImage(renderer.transfer_cmdbuf, img_buffer.handle, image.handle, .transfer_dst_optimal, @intCast(copy_regions.len), copy_regions.ptr);

    const barrier: vk.ImageMemoryBarrier2 = .{
        .srcStageMask = .{ .copy = true },
        .srcAccessMask = .{ .transfer_write = true },
        .dstStageMask = .{ .fragment_shader = true },
        .dstAccessMask = .{ .shader_read = true },
        .oldLayout = .transfer_dst_optimal,
        .newLayout = .read_only_optimal,
        .image = image.handle,
        .subresourceRange = .{
            .aspectMask = .{ .color = true },
            .levelCount = image_ci.mipLevels,
            .layerCount = image_ci.arrayLayers,
        },
    };
    barrier_texinfo.pImageMemoryBarriers = @ptrCast(&barrier);
    vk.cmdPipelineBarrier2(renderer.transfer_cmdbuf, &barrier_texinfo);

    try vk.endCommandBuffer(renderer.transfer_cmdbuf);

    renderer.upload.val += 1;
    const upload_signal: vk.SemaphoreSubmitInfo = .{ .semaphore = renderer.upload.handle, .value = renderer.upload.val };
    const sub_info: vk.SubmitInfo2 = .{
        .commandBufferInfoCount = 1,
        .pCommandBufferInfos = &.{.{ .commandBuffer = renderer.transfer_cmdbuf }},
        .signalSemaphoreInfoCount = 1,
        .pSignalSemaphoreInfos = &.{upload_signal},
    };
    try vk.queueSubmit2(renderer.ctx.queue, 1, @ptrCast(&sub_info), null);

    const waiti: vk.SemaphoreWaitInfo = .{
        .semaphoreCount = 1,
        .pValues = &.{renderer.upload.val},
        .pSemaphores = &.{renderer.upload.handle},
    };
    try vk.waitSemaphores(renderer.ctx.device, &waiti, std.math.maxInt(u64));

    return image;
}

pub const Mesh = struct {
    pub const Offsets = extern struct {
        start_index: u32 = 0,
        index_count: u32 = 0,
        start_vertex: i32 = 0,
    };
    offsets: Offsets = .{},
    material: u32 = 0,
};

pub const Model = struct {
    images: []*ImageR,
    meshes: []Mesh,
};

pub fn unloadModel(renderer: *Renderer, gpa: Allocator, model: *const Model) void {
    for (model.images) |image| {
        renderer.destroyTexture(image);
    }
    gpa.free(model.images);
    gpa.free(model.meshes);
}

// fn getHate(
//     manager: *Renderer,
//     io: Io,
//     gpa: Allocator,
//     ctx: *const Context,
//     cp: vk.CommandPool,
//     gltf: *const Gltf,
//     dir: Io.Dir,
//     model_name: []const u8,
//     tex_type: []const u8,
//     i: usize,
//     info: anytype,
// ) !Hate {
//     const path = gltf.data.images[info.index].uri.?;
//     log.debug("Loading {q}", .{path});
//     const file = try dir.readFileAlloc(io, path, gpa, .unlimited);
//     defer gpa.free(file);
//     const hate = try manager.loadTextureFromMemory(ctx, gpa, cp, file);
//     var buf: [256]u8 = undefined;
//     const name = try std.fmt.bufPrintSentinel(&buf, "{s}:{s}#{}", .{ model_name, tex_type, i }, 0);
//     try vk.nameHandle(ctx.device, manager.getImage(hate.image), name.ptr);
//     return hate;
// }

fn thing(renderer: *Renderer, io: Io, gpa: Allocator, gltf: *Gltf, dir: Io.Dir, info: anytype) !*ImageR {
    const image_path = gltf.data.images[info.index].uri.?;
    log.debug("Loading {q}", .{image_path});
    const file = try dir.readFileAlloc(io, image_path, gpa, .unlimited);
    defer gpa.free(file);
    return renderer.loadTextureFromMemory(gpa, file);
}

fn proccessMaterial(renderer: *Renderer, io: Io, gpa: Allocator, gltf: *Gltf, dir: Io.Dir, material: Gltf.Material, images: *std.ArrayList(*ImageR)) !u32 {
    var mat: st.Material = .{};

    const albedo = material.metallic_roughness.base_color_texture;
    if (albedo) |info| {
        const image = try renderer.thing(io, gpa, gltf, dir, info);
        mat.albedo = renderer.desc_man.appendSampled(renderer.ctx.device, image.view, .read_only_optimal);
        try images.append(gpa, image);
    }
    const metrou = material.metallic_roughness.metallic_roughness_texture;
    if (metrou) |info| {
        const image = try renderer.thing(io, gpa, gltf, dir, info);
        mat.metallic_roughness = renderer.desc_man.appendSampled(renderer.ctx.device, image.view, .read_only_optimal);
        try images.append(gpa, image);
    }
    const normal = material.normal_texture;
    if (normal) |info| {
        const image = try renderer.thing(io, gpa, gltf, dir, info);
        mat.normal = renderer.desc_man.appendSampled(renderer.ctx.device, image.view, .read_only_optimal);
        try images.append(gpa, image);
    }
    const emissive = material.emissive_texture;
    if (emissive) |info| {
        const image = try renderer.thing(io, gpa, gltf, dir, info);
        mat.emissive = renderer.desc_man.appendSampled(renderer.ctx.device, image.view, .read_only_optimal);
        try images.append(gpa, image);
    }
    const ao = material.occlusion_texture;
    if (ao) |info| {
        const image = try renderer.thing(io, gpa, gltf, dir, info);
        mat.occlusion = renderer.desc_man.appendSampled(renderer.ctx.device, image.view, .read_only_optimal);
        try images.append(gpa, image);
    }
    const index = renderer.materials.offset;
    renderer.materials.append(mat);

    return @intCast(index);
}

pub fn loadGltf(renderer: *Renderer, io: Io, gpa: Allocator, path: []const u8) !Model {
    log.debug("Loading {q}", .{path});
    var out: Model = undefined;

    var gltf = Gltf.init(gpa);
    defer gltf.deinit();
    const dirname = Io.Dir.path.dirname(path) orelse ".";
    const dir = try Io.Dir.openDir(.cwd(), io, dirname, .{});
    defer dir.close(io);
    const buffer = try Io.Dir.cwd().readFileAllocOptions(io, path, gpa, .unlimited, .@"4", null);
    defer gpa.free(buffer);
    try gltf.parse(buffer);

    const bins: [][]align(4) const u8 = try gpa.alloc([]align(4) const u8, gltf.data.buffers.len);
    defer gpa.free(bins);
    for (gltf.data.buffers, bins) |buf, *bin| {
        //TODO: fix cook
        _ = buf;
        bin.* = try dir.readFileAllocOptions(io, "bin", gpa, .unlimited, .@"4", null);
    }
    defer for (bins) |bin| {
        gpa.free(bin);
    };

    var images: std.ArrayList(*ImageR) = .empty;
    var meshes: std.ArrayList(Mesh) = .empty;
    for (gltf.data.nodes) |node| {
        const scale: zkf.Vec3 = @bitCast(node.scale);
        const gl_to_vulkan = zkf.Vec3{ .x = 1, .y = -1, .z = -1 };

        const mesh_idx = node.mesh orelse continue;

        const mesh = gltf.data.meshes[mesh_idx];

        for (mesh.primitives) |primitive| {
            const start_index: u32 = @intCast(renderer.indices.offset);
            const start_vertex: i32 = @intCast(renderer.vertices.offset);

            const indices = gltf.data.accessors[primitive.indices orelse return error.NoIndices];
            const index_count: u32 = @intCast(indices.count);

            const material = gltf.data.materials[primitive.material orelse return error.NoMaterial];

            const mat_id = try renderer.proccessMaterial(io, gpa, &gltf, dir, material, &images);

            try meshes.append(gpa, .{
                .offsets = .{
                    .start_index = start_index,
                    .start_vertex = start_vertex,
                    .index_count = index_count,
                },
                .material = mat_id,
            });

            var indices_it = indices.iterator(IndexType, &gltf, bins[gltf.data.buffer_views[indices.buffer_view.?].buffer]);
            while (indices_it.next()) |val| {
                renderer.indices.appendSlice(val);
            }

            var positions: Gltf.Accessor = undefined;
            var normals: Gltf.Accessor = undefined;
            var texcoords: Gltf.Accessor = undefined;
            for (primitive.attributes) |attr| {
                switch (attr) {
                    .position => |val| positions = gltf.data.accessors[val],
                    .normal => |val| normals = gltf.data.accessors[val],
                    .texcoord => |val| texcoords = gltf.data.accessors[val],
                    else => {},
                }
            }

            var pos_it = positions.iterator(f32, &gltf, bins[gltf.data.buffer_views[positions.buffer_view.?].buffer]);
            var norm_it = normals.iterator(f32, &gltf, bins[gltf.data.buffer_views[normals.buffer_view.?].buffer]);
            var tex_it = texcoords.iterator(f32, &gltf, bins[gltf.data.buffer_views[texcoords.buffer_view.?].buffer]);
            for (0..positions.count) |_| {
                const pos: *const zkf.Vec3 = @ptrCast(@alignCast(pos_it.next().?.ptr));
                const norm: *const zkf.Vec3 = @ptrCast(@alignCast(norm_it.next().?.ptr));
                const tex: *const math.Vec2 = @ptrCast(@alignCast(tex_it.next().?.ptr));

                const pos_temp = pos.mul(scale).mul(gl_to_vulkan);
                const norm_flipped = norm.mul(gl_to_vulkan).normalize();
                const w: st.Vertex = .{
                    .pos = pos_temp,
                    .norm = norm_flipped,
                    .uv = tex.*,
                };

                renderer.vertices.append(w);
            }
        }
    }

    out.meshes = try meshes.toOwnedSlice(gpa);
    out.images = try images.toOwnedSlice(gpa);

    return out;
}

pub fn loadObj(manager: *Renderer, arena: std.mem.Allocator, io: *std.Io, path: [*:0]const u8) !Mesh {
    var attrib: c.tinyobj_attrib_t = undefined;
    var shapes_num: usize = 0;
    var shapes: ?[*]c.tinyobj_shape_t = null;

    const vert_start: i32 = @intCast(manager.vertices.offset);
    const idx_start: u32 = @intCast(manager.indices.offset);

    //not doing shi with these
    var materials_num: usize = 0;
    var materials: ?[*]c.tinyobj_material_t = null;

    var ctx: zkf.FileDataCtx = .{
        .io = io,
        .arena = arena,
        .mmaps = .empty,
    };

    const ret = c.tinyobj_parse_obj(&attrib, &shapes, &shapes_num, &materials, &materials_num, path, zkf.get_file_data, &ctx, c.TINYOBJ_FLAG_TRIANGULATE);
    for (ctx.mmaps.items) |*mmap| {
        mmap.destroy(io.*);
    }
    ctx.mmaps.deinit(ctx.arena);
    if (ret != 0) @panic("loading obj failed");

    for (0..attrib.num_faces, attrib.faces) |i, face| {
        const v_start: usize = @intCast(face.v_idx * 3);
        const vn_start: usize = @intCast(face.vn_idx * 3);
        const vt_start: usize = @intCast(face.vt_idx * 2);

        const vert: st.Vertex = .{
            .pos = .{ .x = attrib.vertices[v_start], .y = -attrib.vertices[v_start + 1], .z = attrib.vertices[v_start + 2] },
            .norm = .{ .x = attrib.normals[vn_start], .y = -attrib.normals[vn_start + 1], .z = attrib.normals[vn_start + 2] },
            .uv = .{ .x = attrib.texcoords[vt_start], .y = 1.0 - attrib.texcoords[vt_start] },
        };
        manager.vertices.append(vert);
        manager.indices.append(@as(IndexType, @intCast(i)));
    }
    c.tinyobj_attrib_free(&attrib);
    c.tinyobj_materials_free(materials, materials_num);
    c.tinyobj_shapes_free(shapes, shapes_num);

    return .{
        .offsets = .{
            .start_index = idx_start,
            .index_count = attrib.num_faces,
            .start_vertex = vert_start,
        },
    };
}

pub fn addMesh(manager: *Renderer, indices: []const IndexType, vertices: []const st.Vertex) Mesh {
    const mesh: Mesh = .{
        .start_vertex = @intCast(manager.vert_offset / @sizeOf(st.Vertex)),
        .start_index = @intCast(manager.idx_offset / @sizeOf(IndexType)),
        .index_count = @intCast(indices.len),
    };
    manager.vertices.write(manager.vert_offset, vertices);
    manager.vert_offset += vertices.len * @sizeOf(st.Vertex);
    manager.indices.write(manager.idx_offset, indices);
    manager.idx_offset += indices.len * @sizeOf(IndexType);

    return mesh;
}

//TODO:
pub fn transferToImage(manager: *Renderer, target: ImageHandle, buffer: vk.Buffer, regions: []vk.BufferImageCopy, level_count: u32, layer_count: u32) void {
    const image = manager.getImage(target);

    const transfer_start_barrier: vk.ImageMemoryBarrier2 = .{
        .dstStageMask = .{ .all_transfer = true },
        .dstAccessMask = .{ .transfer_write = true },
        .oldLayout = .undefined,
        .newLayout = .transfer_dst_optimal,
        .image = image,
        .subresourceRange = .{
            .aspectMask = .{ .color = true },
            .levelCount = level_count,
            .layerCount = layer_count,
        },
    };
    var dep_info: vk.DependencyInfo = .{ .imageMemoryBarrierCount = 1, .pImageMemoryBarriers = @ptrCast(&transfer_start_barrier) };

    vk.cmdPipelineBarrier2(manager.command_buffer, &.{});
    vk.cmdCopyBufferToImage(manager.command_buffer, buffer, image, .transfer_dst_optimal, @intCast(regions.len), regions.ptr);

    const texread_barrier: vk.ImageMemoryBarrier2 = .{
        .srcStageMask = .{ .all_transfer = true },
        .srcAccessMask = .{ .transfer_write = true },
        .oldLayout = .transfer_dst_optimal,
        .newLayout = .read_only_optimal,
        .image = image,
        .subresourceRange = .{
            .aspectMask = .{ .color = true },
            .levelCount = level_count,
            .layerCount = layer_count,
        },
    };

    dep_info.pImageMemoryBarriers = @ptrCast(&texread_barrier);
    vk.cmdPipelineBarrier2(manager.command_buffer, &dep_info);
}

/// sets image and format fields on image view
pub fn createTexture(renderer: *Renderer, ci: *const vk.ImageCreateInfo, vci: *vk.ImageViewCreateInfo) !*ImageR {
    //TODO: errdefer all the things
    const image = try renderer.images.create(undefined);
    try vma.createImage(renderer.ctx.vka, ci, &.{ .usage = .auto }, &image.handle, &image.allocation, null);

    vci.image = image.handle;
    vci.format = ci.format;
    try vk.createImageView(renderer.ctx.device, vci, null, &image.view);

    return image;
}

pub fn destroyTexture(renderer: *Renderer, image: *ImageR) void {
    vk.destroyImageView(renderer.ctx.device, image.view, null);
    vma.destroyImage(renderer.ctx.vka, image.handle, image.allocation);
    renderer.images.destroy(image);
}

pub fn createTexture2D(renderer: *Renderer, format: vk.Format, extent: vk.Extent2D, usage: vk.ImageUsageFlags, aspect_mask: vk.ImageAspectFlags) !*ImageR {
    const ci: vk.ImageCreateInfo = .{
        .imageType = .@"2d",
        .samples = .{ .@"1" = true },
        .mipLevels = 1,
        .arrayLayers = 1,

        .usage = usage,
        .format = format,
        .extent = .{ .width = extent.width, .height = extent.height, .depth = 1 },
    };

    var vci: vk.ImageViewCreateInfo = .{
        .viewType = .@"2d",
        .subresourceRange = .{
            .aspectMask = aspect_mask,
            .layerCount = 1,
            .levelCount = 1,
        },
    };

    return renderer.createTexture(&ci, &vci);
}

pub fn loadLevel() void {}
