//TODO: isnt this just a renderer?
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.AssetManager);

const Gltf = @import("zgltf").Gltf;
pub const c = @import("c");
const vk = @import("vk");

const ktx = @import("ktx.zig");
const sdl = @import("sdl.zig");
const vma = @import("vma.zig");
const zkf = @import("zkf.zig");
const math = @import("math.zig");
const gpu = @import("gpu_structs.zig");
const ObjectPool = zkf.ObjectPool;
const Context = zkf.Context;
const Buffer = zkf.Buffer;

const AssetManager = @This();

pub const ImageHandle = enum(u32) {
    empty = std.math.maxInt(u32),
    _,
};
pub const ViewHandle = enum(u32) {
    empty = std.math.maxInt(u32),
    _,
};
pub const ImageR = struct {
    handle: vk.Image,
    allocation: vma.Allocation,
};

//resources
images: ObjectPool(ImageR),

vertices: Buffer,
vert_offset: u64,
indices: Buffer,
idx_offset: u64,

//Descriptors stuff
sampled: ObjectPool(vk.ImageView),
storage: ObjectPool(vk.ImageView),
samplers: ObjectPool(vk.Sampler),

descriptor_set: vk.DescriptorSet,
descriptor_layout: vk.DescriptorSetLayout,
descriptor_pool: vk.DescriptorPool,

//transfer

upload_semaphore: vk.Semaphore,
upload_val: std.atomic.Value(u64),

pub const Limits = struct {
    sampled_image: u32 = 0,
    storage_image: u32 = 0,
    sampler: u32 = 0,

    vertex_buffer_size: u64 = 0,
    index_buffer_size: u64 = 0,
};
const limits: Limits = .{ .sampled_image = 1000, .storage_image = 100, .sampler = 24, .vertex_buffer_size = 1 << 24, .index_buffer_size = 1 << 22 };

pub fn init(ctx: Context, gpa: std.mem.Allocator) !AssetManager {
    var out: AssetManager = undefined;
    out.images = try .init(gpa, limits.sampled_image + limits.storage_image);
    out.sampled = try .init(gpa, limits.sampled_image);
    out.storage = try .init(gpa, limits.storage_image);
    out.samplers = try .init(gpa, limits.sampler);
    out.upload_val = .init(0);

    const semaphore_type: vk.SemaphoreTypeCreateInfo = .{ .semaphoreType = .timeline };
    const semaphore_ci: vk.SemaphoreCreateInfo = .{ .pNext = &semaphore_type };
    try vk.createSemaphore(ctx.device, &semaphore_ci, null, &out.upload_semaphore);

    //descriptor stuff
    const desc_bind_flags: vk.DescriptorSetLayoutBindingFlagsCreateInfo = .{
        .pBindingFlags = &@as([3]vk.DescriptorBindingFlags, @splat(.{ .partially_bound = true, .update_unused_while_pending = false })),
        .bindingCount = 3,
    };
    const bindings = [_]vk.DescriptorSetLayoutBinding{
        .{
            .binding = 0,
            .descriptorCount = limits.sampled_image,
            .descriptorType = .sampled_image,
            .stageFlags = .{ .fragment = true, .vertex = true, .compute = true },
        },
        .{
            .binding = 1,
            .descriptorCount = limits.storage_image,
            .descriptorType = .storage_image,
            .stageFlags = .{ .fragment = true, .vertex = true, .compute = true },
        },
        .{
            .binding = 2,
            .descriptorCount = limits.sampler,
            .descriptorType = .sampler,
            .stageFlags = .{ .fragment = true, .vertex = true, .compute = true },
        },
    };
    const desc_layout_ci: vk.DescriptorSetLayoutCreateInfo = .{
        .pNext = &desc_bind_flags,
        .pBindings = &bindings,
        .bindingCount = 3,
    };
    try vk.createDescriptorSetLayout(ctx.device, &desc_layout_ci, null, &out.descriptor_layout);

    const sizes: []const vk.DescriptorPoolSize = &.{
        .{ .descriptorCount = limits.sampled_image, .type = .sampled_image },
        .{ .descriptorCount = limits.storage_image, .type = .storage_image },
        .{ .descriptorCount = limits.sampler, .type = .sampler },
    };
    const pool_ci: vk.DescriptorPoolCreateInfo = .{
        .maxSets = 1,
        .poolSizeCount = @intCast(sizes.len),
        .pPoolSizes = sizes.ptr,
    };
    try vk.createDescriptorPool(ctx.device, &pool_ci, null, &out.descriptor_pool);

    const set_ai: vk.DescriptorSetAllocateInfo = .{
        .descriptorPool = out.descriptor_pool,
        .descriptorSetCount = 1,
        .pSetLayouts = @ptrCast(&out.descriptor_layout),
    };
    try vk.allocateDescriptorSets(ctx.device, &set_ai, @ptrCast(&out.descriptor_set));

    //default sampler
    const index = try out.samplers.push(undefined);
    const sampler_ci: vk.SamplerCreateInfo = .{
        .magFilter = .linear,
        .minFilter = .linear,
        .mipmapMode = .linear,
        .anisotropyEnable = .True,
        .maxAnisotropy = 8.0,
        .borderColor = .float_transparent_black,
        .maxLod = 11,
    };
    try vk.createSampler(ctx.device, &sampler_ci, null, &out.samplers.pool[index].val);

    const sampler_write: vk.WriteDescriptorSet = .{
        .dstSet = out.descriptor_set,
        .dstBinding = 2,
        .descriptorType = .sampler,
        .descriptorCount = 1,
        .dstArrayElement = 0,
        .pImageInfo = &.{.{ .sampler = out.samplers.pool[index].val }},
    };
    vk.updateDescriptorSets(ctx.device, 1, @ptrCast(&sampler_write), 0, undefined);

    const vertex_ci: vk.BufferCreateInfo = .{
        .size = limits.vertex_buffer_size,
        .usage = .{ .shader_device_address = true },
    };
    out.vertices = try .init(ctx.vka, vertex_ci, .mapped_vram);
    try vk.nameHandle(ctx.device, out.vertices.handle, "Vertices Buffer");
    out.vert_offset = 0;
    const index_ci: vk.BufferCreateInfo = .{
        .size = limits.index_buffer_size,
        .usage = .{ .index_buffer = true },
    };
    out.indices = try .init(ctx.vka, index_ci, .mapped_vram);
    try vk.nameHandle(ctx.device, out.indices.handle, "Indices Buffer");
    out.idx_offset = 0;

    return out;
}

pub fn deinit(manager: *AssetManager, ctx: Context, gpa: std.mem.Allocator) void {
    vk.destroySemaphore(ctx.device, manager.upload_semaphore, null);
    vk.destroyDescriptorPool(ctx.device, manager.descriptor_pool, null);
    vk.destroyDescriptorSetLayout(ctx.device, manager.descriptor_layout, null);

    const sampler = manager.samplers.get(0);
    vk.destroySampler(ctx.device, sampler, null);

    manager.vertices.deinit(ctx.vka);
    manager.indices.deinit(ctx.vka);

    manager.images.deinit(gpa);
    manager.sampled.deinit(gpa);
    manager.storage.deinit(gpa);
    manager.samplers.deinit(gpa);
}

pub const Hate = struct {
    image: ImageHandle,
    sampled: ViewHandle,
};

pub fn loadTextureFromFile(manager: *AssetManager, ctx: *const Context, gpa: std.mem.Allocator, cp: vk.CommandPool, filename: [:0]const u8) !Hate {
    log.debug("attempting to open {q}", .{filename});
    var texture: *ktx.Texture = try .fromNamedFile(filename.ptr, .{ .load_image_data_bit = true });
    defer texture.destroy();
    return loadTexture(manager, ctx, gpa, cp, texture);
}

pub fn loadTextureFromMemory(manager: *AssetManager, ctx: *const Context, gpa: std.mem.Allocator, cp: vk.CommandPool, memory: []const u8) !Hate {
    var texture: *ktx.Texture = try .fromMemory(memory, .{ .load_image_data_bit = true });
    defer texture.destroy();
    return loadTexture(manager, ctx, gpa, cp, texture);
}

pub fn loadTexture(manager: *AssetManager, ctx: *const Context, gpa: std.mem.Allocator, cp: vk.CommandPool, texture: *ktx.Texture) !Hate {
    const format: vk.Format = @enumFromInt(texture.getVkFormat());
    var image_ci: vk.ImageCreateInfo = .{
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

    if (texture.isCubemap) {
        image_ci.arrayLayers = texture.numFaces;
        image_ci.flags.cube_compatible = true;
    }

    const image_id = try manager.allocImage(ctx, image_ci);
    const image = manager.getImage(image_id);
    errdefer manager.freeImage(ctx, image_id);

    //transfer

    const img_buffer = try Buffer.init(ctx.vka, .{ .size = texture.dataSize, .usage = .{ .transfer_src = true } }, .mapped_vram);
    defer img_buffer.deinit(ctx.vka);
    img_buffer.write(0, texture.pData[0..texture.dataSize]);

    var cmd_buf: vk.CommandBuffer = undefined;
    const cmd_buf_ai: vk.CommandBufferAllocateInfo = .{ .commandPool = cp, .commandBufferCount = 1, .level = .primary };
    try vk.allocateCommandBuffers(ctx.device, &cmd_buf_ai, @ptrCast(&cmd_buf));
    defer vk.freeCommandBuffers(ctx.device, cp, 1, @ptrCast(&cmd_buf));

    const cmd_binfo: vk.CommandBufferBeginInfo = .{ .flags = .{ .one_time_submit = true } };
    try vk.beginCommandBuffer(cmd_buf, &cmd_binfo);

    const mem_barrier: vk.ImageMemoryBarrier2 = .{
        .dstStageMask = .{ .all_transfer = true },
        .dstAccessMask = .{ .transfer_write = true },
        .oldLayout = .undefined,
        .newLayout = .transfer_dst_optimal,
        .image = image,
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
    vk.cmdPipelineBarrier2(cmd_buf, &barrier_texinfo);

    const copy_regions = try gpa.alloc(vk.BufferImageCopy, image_ci.mipLevels * image_ci.arrayLayers);
    defer gpa.free(copy_regions);
    for (0..image_ci.arrayLayers) |i| {
        const layer: u32 = @intCast(i);
        for (0..image_ci.mipLevels) |j| {
            const level: u32 = @intCast(j);
            copy_regions[i * image_ci.mipLevels + j] = vk.BufferImageCopy{
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
    vk.cmdCopyBufferToImage(cmd_buf, img_buffer.handle, image, .transfer_dst_optimal, @intCast(copy_regions.len), copy_regions.ptr);

    const texread_barrier: vk.ImageMemoryBarrier2 = .{
        .srcStageMask = .{ .all_transfer = true },
        .srcAccessMask = .{ .transfer_write = true },
        .oldLayout = .transfer_dst_optimal,
        .newLayout = .read_only_optimal,
        .image = image,
        .subresourceRange = .{
            .aspectMask = .{ .color = true },
            .levelCount = image_ci.mipLevels,
            .layerCount = image_ci.arrayLayers,
        },
    };
    barrier_texinfo.pImageMemoryBarriers = @ptrCast(&texread_barrier);
    vk.cmdPipelineBarrier2(cmd_buf, &barrier_texinfo);
    try vk.endCommandBuffer(cmd_buf);

    const fetch = manager.upload_val.fetchAdd(1, .seq_cst) + 1;
    const upload_signal: vk.SemaphoreSubmitInfo = .{ .semaphore = manager.upload_semaphore, .value = fetch };
    const sub_info: vk.SubmitInfo2 = .{
        .commandBufferInfoCount = 1,
        .pCommandBufferInfos = &.{.{ .commandBuffer = cmd_buf }},
        .signalSemaphoreInfoCount = 1,
        .pSignalSemaphoreInfos = &.{upload_signal},
    };
    try vk.queueSubmit2(ctx.queue, 1, @ptrCast(&sub_info), null);

    //end transfer

    var view_ci: vk.ImageViewCreateInfo = .{
        .format = format,
        .image = image,
        .subresourceRange = .{
            .layerCount = image_ci.arrayLayers,
            .levelCount = image_ci.mipLevels,
            .aspectMask = .{ .color = true },
        },
    };
    if (texture.isCubemap) {
        view_ci.viewType = .cube;
    } else view_ci.viewType = .@"2d";

    const view_id = try manager.allocSampledImage(ctx, view_ci);

    const waiti: vk.SemaphoreWaitInfo = .{
        .semaphoreCount = 1,
        .pValues = &.{fetch},
        .pSemaphores = &.{manager.upload_semaphore},
    };
    try vk.waitSemaphores(ctx.device, &waiti, std.math.maxInt(u64));

    return .{
        .image = image_id,
        .sampled = view_id,
    };
}

pub const Material = extern struct {
    albedo: ViewHandle = .empty,
    metallic_roughness: ViewHandle = .empty,
    normal: ViewHandle = .empty,
    occlusion: ViewHandle = .empty,
    emissive: ViewHandle = .empty,
};

pub const Mesh = extern struct {
    start_index: u32 = 0,
    index_count: u32 = 0,
    start_vertex: i32 = 0,
};

pub const Model = struct {
    materials: []Material,
    images: []ImageHandle,
    meshes: []Mesh,
};

fn getHate(
    manager: *AssetManager,
    io: Io,
    gpa: Allocator,
    ctx: *const Context,
    cp: vk.CommandPool,
    gltf: *const Gltf,
    dir: Io.Dir,
    model_name: []const u8,
    tex_type: []const u8,
    i: usize,
    info: anytype,
) !Hate {
    const path = gltf.data.images[info.index].uri.?;
    log.debug("Loading {q}", .{path});
    const file = try dir.readFileAlloc(io, path, gpa, .unlimited);
    defer gpa.free(file);
    const hate = try manager.loadTextureFromMemory(ctx, gpa, cp, file);
    var buf: [256]u8 = undefined;
    const name = try std.fmt.bufPrintSentinel(&buf, "{s}:{s}#{}", .{ model_name, tex_type, i }, 0);
    try vk.nameHandle(ctx.device, manager.getImage(hate.image), name.ptr);
    return hate;
}

const IndexType = u32;
pub fn loadGltf(manager: *AssetManager, ctx: *const Context, io: Io, gpa: std.mem.Allocator, cp: vk.CommandPool, path: []const u8) !Model {
    log.debug("Loading {q}", .{path});

    var out: Model = undefined;

    var gltf = Gltf.init(gpa);
    defer gltf.deinit();
    const dirname = Io.Dir.path.dirname(path) orelse ".";
    const model_name = Io.Dir.path.stem(path);
    const dir = try Io.Dir.openDir(.cwd(), io, dirname, .{});
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

    //TODO: materials should probably be a buffer on manager
    out.materials = try gpa.alloc(Material, gltf.data.materials.len);
    @memset(out.materials, .{});

    var images: std.ArrayList(ImageHandle) = .empty;
    for (gltf.data.materials, 0..) |material, i| {
        log.debug("material #{} for {q}", .{ i, path });
        const albedo = material.metallic_roughness.base_color_texture;
        if (albedo) |info| {
            const hate = try manager.getHate(io, gpa, ctx, cp, &gltf, dir, model_name, "albedo", i, info);
            out.materials[i].albedo = hate.sampled;
            try images.append(gpa, hate.image);
        }
        const metrou = material.metallic_roughness.metallic_roughness_texture;
        if (metrou) |info| {
            const hate = try manager.getHate(io, gpa, ctx, cp, &gltf, dir, model_name, "met_rough", i, info);
            out.materials[i].metallic_roughness = hate.sampled;
            try images.append(gpa, hate.image);
        }
        const normal = material.normal_texture;
        if (normal) |info| {
            const hate = try manager.getHate(io, gpa, ctx, cp, &gltf, dir, model_name, "normal", i, info);
            out.materials[i].normal = hate.sampled;
            try images.append(gpa, hate.image);
        }
        const emissive = material.emissive_texture;
        if (emissive) |info| {
            const hate = try manager.getHate(io, gpa, ctx, cp, &gltf, dir, model_name, "emissive", i, info);
            out.materials[i].emissive = hate.sampled;
            try images.append(gpa, hate.image);
        }
        const ao = material.occlusion_texture;
        if (ao) |info| {
            const hate = try manager.getHate(io, gpa, ctx, cp, &gltf, dir, model_name, "ao", i, info);
            out.materials[i].occlusion = hate.sampled;
            try images.append(gpa, hate.image);
        }
    }

    var meshes: std.ArrayList(Mesh) = .empty;
    for (gltf.data.nodes) |node| {
        const scale: zkf.Vec3 = @bitCast(node.scale);
        const gl_to_vulkan = zkf.Vec3{ .x = 1, .y = -1, .z = -1 };

        const mesh_idx = node.mesh orelse continue;

        const mesh = gltf.data.meshes[mesh_idx];

        for (mesh.primitives) |primitive| {
            const start_index: u32 = @intCast(manager.idx_offset / @sizeOf(IndexType));
            const start_vertex: i32 = @intCast(manager.vert_offset / @sizeOf(gpu.Vertex));

            const indices = gltf.data.accessors[primitive.indices orelse return error.NoIndices];
            const index_count: u32 = @intCast(indices.count);

            try meshes.append(gpa, .{ .start_index = start_index, .start_vertex = start_vertex, .index_count = index_count });

            const material = gltf.data.materials[primitive.material orelse return error.NoMaterial];
            _ = material;

            var indices_it = indices.iterator(IndexType, &gltf, bins[gltf.data.buffer_views[indices.buffer_view.?].buffer]);
            while (indices_it.next()) |val| {
                manager.indices.write(manager.idx_offset, val);
                manager.idx_offset += @sizeOf(u32);
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
                const w: gpu.Vertex = .{
                    .pos = pos_temp,
                    .norm = norm_flipped,
                    .uv = tex.*,
                };

                manager.vertices.write(manager.vert_offset, w);
                manager.vert_offset += @sizeOf(gpu.Vertex);
            }
        }
    }

    out.meshes = try meshes.toOwnedSlice(gpa);
    out.images = try images.toOwnedSlice(gpa);

    return out;
}

pub fn loadObj(manager: *AssetManager, arena: std.mem.Allocator, io: *std.Io, path: [*:0]const u8) !Mesh {
    var attrib: c.tinyobj_attrib_t = undefined;
    var shapes_num: usize = 0;
    var shapes: ?[*]c.tinyobj_shape_t = null;

    const vert_start: u32 = @intCast(manager.vert_offset);
    const idx_start: u32 = @intCast(manager.idx_offset);

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

        const vert: gpu.Vertex = .{
            .pos = .{ .x = attrib.vertices[v_start], .y = -attrib.vertices[v_start + 1], .z = attrib.vertices[v_start + 2] },
            .norm = .{ .x = attrib.normals[vn_start], .y = -attrib.normals[vn_start + 1], .z = attrib.normals[vn_start + 2] },
            .uv = .{ .x = attrib.texcoords[vt_start], .y = 1.0 - attrib.texcoords[vt_start] },
        };
        manager.vertices.write(manager.vert_offset, vert);
        manager.vert_offset += @sizeOf(gpu.Vertex);
        manager.indices.write(manager.idx_offset, @as(IndexType, @intCast(i)));
        manager.idx_offset += @sizeOf(IndexType);
    }
    c.tinyobj_attrib_free(&attrib);
    c.tinyobj_materials_free(materials, materials_num);
    c.tinyobj_shapes_free(shapes, shapes_num);

    return .{
        .start_index = idx_start / @sizeOf(IndexType),
        .index_count = attrib.num_faces,
        .start_vertex = @intCast(vert_start / @sizeOf(gpu.Vertex)),
    };
}

pub fn addMesh(manager: *AssetManager, indices: []const IndexType, vertices: []const gpu.Vertex) Mesh {
    const mesh: Mesh = .{
        .start_vertex = @intCast(manager.vert_offset / @sizeOf(gpu.Vertex)),
        .start_index = @intCast(manager.idx_offset / @sizeOf(IndexType)),
        .index_count = @intCast(indices.len),
    };
    manager.vertices.write(manager.vert_offset, vertices);
    manager.vert_offset += vertices.len * @sizeOf(gpu.Vertex);
    manager.indices.write(manager.idx_offset, indices);
    manager.idx_offset += indices.len * @sizeOf(IndexType);

    return mesh;
}

//TODO:
pub fn transferToImage(manager: *AssetManager, target: ImageHandle, buffer: vk.Buffer, regions: []vk.BufferImageCopy, level_count: u32, layer_count: u32) void {
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

pub fn allocImage(manager: *AssetManager, ctx: *const Context, ci: vk.ImageCreateInfo) !ImageHandle {
    const idx = try manager.images.push(undefined);
    const image = manager.images.getPtr(idx);
    const ai: vma.AllocationCreateInfo = .{ .usage = .auto };
    try vma.createImage(ctx.vka, &ci, &ai, &image.handle, &image.allocation, null);
    return @enumFromInt(idx);
}

pub fn freeImage(manager: *AssetManager, ctx: *const Context, handle: ImageHandle) void {
    const idx = @intFromEnum(handle);
    const image = manager.images.get(idx);
    vma.destroyImage(ctx.vka, image.handle, image.allocation);
    manager.images.pop(idx);
}

pub fn getImage(manager: *AssetManager, handle: ImageHandle) vk.Image {
    return manager.images.get(@intFromEnum(handle)).handle;
}

pub fn allocSampledImage(manager: *AssetManager, ctx: *const Context, ci: vk.ImageViewCreateInfo) !ViewHandle {
    const idx = try manager.sampled.push(undefined);
    const view = manager.sampled.getPtr(idx);
    try vk.createImageView(ctx.device, &ci, null, view);

    const write: vk.WriteDescriptorSet = .{
        .dstSet = manager.descriptor_set,
        .dstBinding = 0,
        .descriptorType = .sampled_image,
        .descriptorCount = 1,
        .dstArrayElement = idx,
        .pImageInfo = &.{.{ .imageView = view.*, .imageLayout = .read_only_optimal }},
    };
    vk.updateDescriptorSets(ctx.device, 1, @ptrCast(&write), 0, undefined);

    return @enumFromInt(idx);
}

pub fn freeSampledImage(manager: *AssetManager, ctx: *const Context, handle: ViewHandle) void {
    if (handle == .empty) return;
    const idx: u32 = @intFromEnum(handle);
    const view = manager.sampled.get(idx);
    vk.destroyImageView(ctx.device, view, null);
    manager.sampled.pop(idx);
}

pub fn getSampledImage(manager: *AssetManager, handle: ViewHandle) vk.ImageView {
    return manager.sampled.get(@intFromEnum(handle));
}

pub fn allocStorageImage(manager: *AssetManager, ctx: *const Context, ci: vk.ImageViewCreateInfo) !ViewHandle {
    const idx = try manager.storage.push(undefined);
    const view = manager.storage.getPtr(idx);
    try vk.createImageView(ctx.device, &ci, null, view);

    const write: vk.WriteDescriptorSet = .{
        .dstSet = manager.descriptor_set,
        .dstBinding = 1,
        .descriptorType = .storage_image,
        .descriptorCount = 1,
        .dstArrayElement = idx,
        .pImageInfo = &.{.{ .imageView = view.*, .imageLayout = .general }},
    };
    vk.updateDescriptorSets(ctx.device, 1, @ptrCast(&write), 0, undefined);

    return @enumFromInt(idx);
}

pub fn freeStorageImage(manager: *AssetManager, ctx: *const Context, handle: ViewHandle) void {
    const idx: u32 = @intFromEnum(handle);
    const view = manager.storage.get(idx);
    vk.destroyImageView(ctx.device, view, null);
    manager.storage.pop(idx);
}

pub fn getStorageImage(manager: *AssetManager, handle: ViewHandle) vk.ImageView {
    return manager.storage.get(@intFromEnum(handle));
}

pub fn popHate(manager: *AssetManager, ctx: *const Context, hate: Hate) void {
    manager.freeImage(ctx, hate.image);
    manager.freeSampledImage(ctx, hate.sampled);
}

pub fn loadLevel() void {}
