const std = @import("std");
const Io = std.Io;

pub const c = @import("c");
const gltf = @import("zgltf").Gltf;
const vk = @import("vk");

const ktx = @import("ktx.zig");
const sdl = @import("sdl.zig");
const vma = @import("vma.zig");
const zkf = @import("zkf.zig");
const ObjectPool = zkf.ObjectPool;
const Context = zkf.Context;
const Buffer = zkf.Buffer;

const log = std.log.scoped(.AssetManager);

const AssetManager = @This();

pub const ImageHandle = enum(u32) { _ };
pub const ViewHandle = enum(u32) { _ };
pub const ImageR = struct {
    handle: vk.Image,
    allocation: vma.Allocation,
};

//resources

images: ObjectPool(ImageR),

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
};
const limits: Limits = .{ .sampled_image = 1000, .storage_image = 100, .sampler = 24 };

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

    return out;
}

pub fn deinit(manager: *AssetManager, ctx: Context, gpa: std.mem.Allocator) void {
    vk.destroySemaphore(ctx.device, manager.upload_semaphore, null);
    vk.destroyDescriptorPool(ctx.device, manager.descriptor_pool, null);
    vk.destroyDescriptorSetLayout(ctx.device, manager.descriptor_layout, null);

    const sampler = manager.samplers.get(0);
    vk.destroySampler(ctx.device, sampler, null);

    manager.images.deinit(gpa);
    manager.sampled.deinit(gpa);
    manager.storage.deinit(gpa);
    manager.samplers.deinit(gpa);
}

pub const Hate = struct {
    image: ImageHandle,
    sampled: ViewHandle,
};

pub fn loadTexture(manager: *AssetManager, ctx: *const Context, gpa: std.mem.Allocator, cp: vk.CommandPool, filename: [:0]const u8) !Hate {
    log.debug("attempting to open {q}", .{filename});

    var texture: *ktx.Texture = try .fromNamedFile(filename.ptr, .{ .load_image_data_bit = true });
    defer texture.destroy();

    const format = texture.getVkFormat();
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
        // .dstStageMask = .{ .fragment_shader = true },
        // .dstAccessMask = .{ .shader_read = true },
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
    albedo: ViewHandle,
    metallic_roughness: ViewHandle,
    normal: ViewHandle,
    occlusion: ViewHandle,
    emissive: ViewHandle,
};
pub const Model = struct {};

pub fn loadGltf(manager: *AssetManager, ctx: Context, io: Io, gpa: std.mem.Allocator, cp: vk.CommandPool, path: []const u8) !Material {
    log.debug("load model {q}", .{path});
    var model = gltf.init(gpa);
    defer model.deinit();
    const dir = Io.Dir.path.dirname(path) orelse ".";
    const buffer = try Io.Dir.cwd().readFileAllocOptions(io, path, gpa, .unlimited, .@"4", null);
    defer gpa.free(buffer);
    try model.parse(buffer);
    const mat = model.data.materials[0];

    const albedo = mat.metallic_roughness.base_color_texture orelse return error.MissingTexture;
    const metallic_roughness = mat.metallic_roughness.metallic_roughness_texture orelse return error.MissingTexture;
    const normal = mat.normal_texture orelse return error.MissingTexture;
    const occlusion = mat.occlusion_texture orelse return error.MissingTexture;
    const emissive = mat.emissive_texture orelse return error.MissingTexture;

    const emissive_handle = try manager.loadTexture(ctx, gpa, cp, try makePath(&model.data, emissive, dir));
    const occlusion_handle = try manager.loadTexture(ctx, gpa, cp, try makePath(&model.data, occlusion, dir));
    const normal_handle = try manager.loadTexture(ctx, gpa, cp, try makePath(&model.data, normal, dir));
    const metallic_roughness_handle = try manager.loadTexture(ctx, gpa, cp, try makePath(&model.data, metallic_roughness, dir));
    const albedo_handle = try manager.loadTexture(ctx, gpa, cp, try makePath(&model.data, albedo, dir));

    return .{
        .albedo = albedo_handle.sampled,
        .metallic_roughness = metallic_roughness_handle.sampled,
        .normal = normal_handle.sampled,
        .emissive = emissive_handle.sampled,
        .occlusion = occlusion_handle.sampled,
    };
}

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
    const idx: u32 = @intFromEnum(handle);
    const view = manager.sampled.get(idx);
    vk.destroyImageView(ctx.device, view, null);
    manager.sampled.pop(idx);
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

inline fn makePath(data: *const gltf.Data, info: anytype, dir: []const u8) ![:0]const u8 {
    var buf: [512]u8 = undefined;
    return std.fmt.bufPrintSentinel(&buf, "{s}/{s}", .{ dir, data.images[info.index].uri.? }, 0);
}

pub fn popImage(manager: *AssetManager, ctx: Context, handle: ImageHandle) void {
    const idx = @intFromEnum(handle);
    const image = manager.images.pool[idx].val;
    manager.images.pop(idx);
    vma.destroyImage(ctx.vka, image.handle, image.allocation);
}

pub fn popView(manager: *AssetManager, ctx: Context, handle: ViewHandle) void {
    const idx = @intFromEnum(handle);
    const view = manager.sampled.pool[idx].val;
    manager.sampled.pop(idx);
    vk.destroyImageView(ctx.device, view, null);
}

pub fn popHate(manager: *AssetManager, ctx: Context, hate: Hate) void {
    manager.popImage(ctx, hate.image);
    manager.popView(ctx, hate.sampled);
}

pub fn loadLevel() void {}
