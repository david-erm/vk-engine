const std = @import("std");
const Io = std.Io;
const log = std.log.scoped(.howtovulkan);

const vk = @import("vk");
const shaders = @import("shaders");

const zkf = @import("zkf.zig");
const sdl = @import("sdl.zig");
const vma = @import("vma.zig");
const ktx = @import("ktx.zig");
const c = zkf.c;

const Vertex = zkf.Vertex;
const Vec3 = zkf.Vec3;
const Vec4 = zkf.Vec4;
const Mat4 = zkf.Mat4;
const Quat = zkf.Quat;
const Vec2 = zkf.Vec2;
const Pose = zkf.Pose;
const Camera = zkf.Camera;
const Texture = zkf.Texture;
const ShaderDataBuffer = zkf.ShaderDataBuffer;

pub const ShaderData = extern struct {
    projection: Mat4 = .zero,
    ortho: Mat4 = .zero,
    cam: Pose = .{},
    poses: [5]Pose = @splat(.{}),
    light_pos: Vec4 = .{ .x = 0.0, .y = -4.0, .z = 3.0, .w = 0.0 },
    selected: u32 = 1,
};

//really should be part of an atlas, billion small textures
const Character = struct {
    tex: zkf.Texture,
    width: u32,
    height: u32,
    bearingx: i32,
    bearingy: i32,
    advance: u32,
};
var char_map: std.AutoHashMapUnmanaged(u8, Character) = .empty;

const max_frames = 2;
var cam: Camera = .{ .pose = .{ .pos = .{ .z = 6.0 }, .rot = .identity, .extra = 0 } };
var fullscreen = false;

var mouse_mode = true;
var mouse_pos: Vec2 = .{ .x = 0, .y = 0 };
var mouse_state: sdl.MouseButtonFlags = .{};

var space_advance: u32 = undefined;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    var io = init.io;

    var ctx: zkf.Context = try .init(arena);
    defer ctx.deinit();
    var rctx: zkf.RenderContext = try .init(&ctx, arena, 1920, 1080, "testing", max_frames);
    defer rctx.deinit(ctx);

    //mem
    var mem_props: vk.PhysicalDeviceMemoryProperties2 = .{};
    vk.getPhysicalDeviceMemoryProperties2(ctx.pdevice, &mem_props);
    var m3: vk.PhysicalDeviceMaintenance3Properties = .{};
    var idk: vk.PhysicalDeviceProperties2 = .{ .pNext = &m3 };
    vk.getPhysicalDeviceProperties2(ctx.pdevice, &idk);

    const memtype_idx: u32 = for (0..mem_props.memoryProperties.memoryTypeCount) |i| {
        const flags = mem_props.memoryProperties.memoryTypes[i].propertyFlags;
        if (flags.device_local and flags.host_visible and flags.host_coherent) break @intCast(i);
    } else return error.NoSuitableMemory;

    const mem_smth: vk.MemoryAllocateFlagsInfo = .{ .flags = .{ .device_address = true } };
    const mem_ci: vk.MemoryAllocateInfo = .{ .allocationSize = 0x200000, .memoryTypeIndex = memtype_idx, .pNext = &mem_smth };
    var mem: vk.DeviceMemory = undefined;
    try vk.allocateMemory(ctx.device, &mem_ci, null, &mem);
    defer vk.freeMemory(ctx.device, mem, null);

    var pointer: [*]align(4096) u8 = undefined;
    try vk.mapMemory(ctx.device, mem, 0, 4096, .{}, @ptrCast(&pointer));
    defer vk.unmapMemory(ctx.device, mem);
    log.info("{*}, {*}", .{ pointer, pointer + 1 });
    //end mem

    _ = sdl.setWindowRelativeMouseMode(rctx.window, true);
    const suzanne = try zkf.loadObj(arena, &io, "assets/suzanne.obj");
    const cube = try zkf.loadObj(arena, &io, "assets/cube.obj");

    const vBufferSize: vk.DeviceSize = @sizeOf(Vertex) * suzanne.vertices.items.len;
    const iBufferSize: vk.DeviceSize = @sizeOf(u32) * suzanne.indices.items.len;
    const suzanne_buffer = zkf.Buffer.init(ctx.vka, .{ .size = vBufferSize + iBufferSize, .usage = .{ .index_buffer = true, .vertex_buffer = true } }, .mapped_vram);
    defer suzanne_buffer.deinit(ctx.vka);
    suzanne_buffer.write(0, suzanne.vertices.items);
    suzanne_buffer.write(vBufferSize, suzanne.indices.items);

    const plane_buffer = zkf.Buffer.init(ctx.vka, .{
        .size = @sizeOf(f32) * plane_vertices.len + @sizeOf(u32) * quad_indices.len,
        .usage = .{ .index_buffer = true, .vertex_buffer = true },
    }, .mapped_vram);
    defer plane_buffer.deinit(ctx.vka);
    plane_buffer.write(0, plane_vertices);
    plane_buffer.write(@sizeOf(f32) * plane_vertices.len, quad_indices);

    const cube_buffer = zkf.Buffer.init(ctx.vka, .{
        .size = @sizeOf(Vertex) * cube.vertices.items.len + @sizeOf(u32) * cube.indices.items.len,
        .usage = .{ .index_buffer = true, .vertex_buffer = true },
    }, .mapped_vram);
    defer cube_buffer.deinit(ctx.vka);
    cube_buffer.write(0, cube.vertices.items);
    cube_buffer.write(@sizeOf(Vertex) * cube.vertices.items.len, cube.indices.items);

    const quad_size = @sizeOf(f32) * 6 * 4;
    const text_quad = zkf.Buffer.init(ctx.vka, .{
        .size = quad_size * 100,
        .usage = .{ .vertex_buffer = true },
    }, .mapped_vram);
    defer text_quad.deinit(ctx.vka);

    var commandPool: vk.CommandPool = undefined;
    var command_buffers: [max_frames]vk.CommandBuffer = undefined;
    defer vk.destroyCommandPool(ctx.device, commandPool, null);
    {
        const commandPoolCI: vk.CommandPoolCreateInfo = .{ .flags = .{ .reset_command_buffer = true }, .queueFamilyIndex = ctx.qfamily };
        try vk.createCommandPool(ctx.device, &commandPoolCI, null, &commandPool);
        const cmdBufferCI: vk.CommandBufferAllocateInfo = .{ .commandPool = commandPool, .commandBufferCount = max_frames, .level = .primary };
        try vk.allocateCommandBuffers(ctx.device, &cmdBufferCI, &command_buffers);
    }

    //textures
    var texture_descriptors: [4 + 128]vk.DescriptorImageInfo = undefined;

    const skybox = try zkf.loadImage(arena, "assets/skybox.ktx2", ctx.device, ctx.vka, ctx.queue, commandPool);
    defer vma.destroyImage(ctx.vka, skybox.image, skybox.alon);
    defer vk.destroyImageView(ctx.device, skybox.view, null);
    defer vk.destroySampler(ctx.device, skybox.sampler, null);
    texture_descriptors[3].imageLayout = .read_only_optimal;
    texture_descriptors[3].sampler = skybox.sampler;
    texture_descriptors[3].imageView = skybox.view;

    var textures: [3]Texture = undefined;
    defer for (textures) |texture| {
        vk.destroySampler(ctx.device, texture.sampler, null);
        vk.destroyImageView(ctx.device, texture.view, null);
        vma.destroyImage(ctx.vka, texture.image, texture.alon);
    };
    for ((&textures)[0..3], 0..) |*texture, i| {
        var buf: [128]u8 = @splat(0);
        const filename = try std.fmt.bufPrintSentinel(&buf, "assets/suzanne{}.ktx", .{i}, 0);

        texture.* = try zkf.loadImage(arena, filename, ctx.device, ctx.vka, ctx.queue, commandPool);

        texture_descriptors[i] = .{
            .sampler = texture.sampler,
            .imageView = texture.view,
            .imageLayout = .read_only_optimal,
        };
    }

    //fonts
    var ft: c.FT_Library = undefined;
    if (c.FT_Init_FreeType(&ft) != 0) {
        log.info("Failed to init freetype.", .{});
        return error.Freetype;
    }
    var face: c.FT_Face = undefined;
    if (c.FT_New_Face(ft, "/usr/share/fonts/ibm-plex-sans-fonts/IBMPlexSans-Regular.otf", 0, &face) != 0) {
        log.info("Failed to init face", .{});
        return error.Face;
    }
    if (c.FT_Set_Pixel_Sizes(face, 0, 64) != 0) @panic("");

    for (0..128) |i| {
        if (c.FT_Load_Char(face, i, c.FT_LOAD_RENDER) != 0) {
            log.info("failed to load {c}", .{@as(u8, @intCast(i))});
            continue;
        }
        const glyph = face.*.glyph.*;
        const ci: vk.ImageCreateInfo = .{
            .imageType = .@"2d",
            .format = .r8_unorm,
            .extent = .{ .width = glyph.bitmap.width, .height = glyph.bitmap.rows, .depth = 1 },
            .samples = .{ .@"1" = true },
            .usage = .{ .transfer_dst = true, .sampled = true },
            .mipLevels = 1,
            .arrayLayers = 1,
        };
        const ai: vma.AllocationCreateInfo = .{ .usage = .auto };

        var img: vk.Image = undefined;
        var allocation: vma.Allocation = undefined;
        const rs = vma.createImage(ctx.vka, &ci, &ai, &img, &allocation, null);
        if (@intFromEnum(rs) != 0) {
            log.warn("Could not create image for {c}({d}) : {s}", .{ @as(u8, @intCast(i)), @as(u8, @intCast(i)), @tagName(rs) });
            space_advance = @intCast(glyph.advance.x);
            continue;
        }

        const transfer_ci: vk.BufferCreateInfo = .{ .size = glyph.bitmap.rows * glyph.bitmap.width, .usage = .{ .transfer_src = true } };
        const transfer_ai: vma.AllocationCreateInfo = .{ .usage = .auto, .flags = .{ .mapped_bit = true, .host_access_sequential_write_bit = true } };
        const transfer_buffer: zkf.Buffer = .init(ctx.vka, transfer_ci, transfer_ai);
        defer transfer_buffer.deinit(ctx.vka);
        transfer_buffer.write(0, glyph.bitmap.buffer[0 .. glyph.bitmap.rows * glyph.bitmap.width]);

        const fence_ci: vk.FenceCreateInfo = .{};
        var fence: vk.Fence = undefined;
        try vk.createFence(ctx.device, &fence_ci, null, &fence);
        defer vk.destroyFence(ctx.device, fence, null);

        var cmd_buf: vk.CommandBuffer = undefined;
        const cmd_buf_ai: vk.CommandBufferAllocateInfo = .{ .commandPool = commandPool, .commandBufferCount = 1, .level = .primary };
        try vk.allocateCommandBuffers(ctx.device, &cmd_buf_ai, @ptrCast(&cmd_buf));
        defer vk.freeCommandBuffers(ctx.device, commandPool, 1, @ptrCast(&cmd_buf));

        const cmd_binfo: vk.CommandBufferBeginInfo = .{ .flags = .{ .one_time_submit = true } };
        {
            try vk.beginCommandBuffer(cmd_buf, &cmd_binfo);

            const layout_barrier: vk.ImageMemoryBarrier2 = .{
                .dstStageMask = .{ .all_transfer = true },
                .dstAccessMask = .{ .transfer_write = true },
                .oldLayout = .undefined,
                .newLayout = .transfer_dst_optimal,
                .image = img,
                .subresourceRange = .{
                    .aspectMask = .{ .color = true },
                    .levelCount = 1,
                    .layerCount = 1,
                },
            };
            var barrier_texinfo: vk.DependencyInfo = .{
                .imageMemoryBarrierCount = 1,
                .pImageMemoryBarriers = @ptrCast(&layout_barrier),
            };
            vk.cmdPipelineBarrier2(cmd_buf, &barrier_texinfo);

            const copy_regions: vk.BufferImageCopy = .{
                .imageSubresource = .{
                    .aspectMask = .{ .color = true },
                    .layerCount = 1,
                },
                .imageExtent = .{
                    .depth = 1,
                    .width = glyph.bitmap.width,
                    .height = glyph.bitmap.rows,
                },
            };
            vk.cmdCopyBufferToImage(cmd_buf, transfer_buffer.handle, img, .transfer_dst_optimal, 1, &.{copy_regions});

            const texread_barrier: vk.ImageMemoryBarrier2 = .{
                .srcStageMask = .{ .all_transfer = true },
                .srcAccessMask = .{ .transfer_write = true },
                .dstStageMask = .{ .fragment_shader = true },
                .dstAccessMask = .{ .shader_read = true },
                .oldLayout = .transfer_dst_optimal,
                .newLayout = .read_only_optimal,
                .image = img,
                .subresourceRange = .{
                    .aspectMask = .{ .color = true },
                    .levelCount = 1,
                    .layerCount = 1,
                },
            };
            barrier_texinfo.pImageMemoryBarriers = @ptrCast(&texread_barrier);
            vk.cmdPipelineBarrier2(cmd_buf, &barrier_texinfo);

            try vk.endCommandBuffer(cmd_buf);
        }

        const submiti: vk.SubmitInfo = .{
            .commandBufferCount = 1,
            .pCommandBuffers = &.{cmd_buf},
        };
        try vk.queueSubmit(ctx.queue, 1, &.{submiti}, fence);
        try vk.waitForFences(ctx.device, 1, &.{fence}, .True, std.math.maxInt(u64));

        const sampler_ci: vk.SamplerCreateInfo = .{
            .minFilter = .linear,
            .magFilter = .linear,
            .addressModeU = .clamp_to_border,
            .addressModeV = .clamp_to_border,
            .addressModeW = .clamp_to_border,
            .anisotropyEnable = .True,
            .maxAnisotropy = 8.0,
            .borderColor = .float_transparent_black,
            .maxLod = 1,
        };
        var sampler: vk.Sampler = undefined;
        try vk.createSampler(ctx.device, &sampler_ci, null, &sampler);

        const view_ci: vk.ImageViewCreateInfo = .{
            .format = .r8_unorm,
            .image = img,
            .viewType = .@"2d",
            .subresourceRange = .{
                .aspectMask = .{ .color = true },
                .layerCount = 1,
                .levelCount = 1,
            },
        };
        var view: vk.ImageView = undefined;
        try vk.createImageView(ctx.device, &view_ci, null, &view);

        try char_map.put(arena, @intCast(i), .{
            .tex = .{
                .alon = allocation,
                .image = img,
                .view = view,
                .sampler = sampler,
            },
            .width = glyph.bitmap.width,
            .height = glyph.bitmap.rows,
            .bearingx = glyph.bitmap_left,
            .bearingy = glyph.bitmap_top,
            .advance = @intCast(face.*.glyph.*.advance.x),
        });
        texture_descriptors[i + 4] = .{
            .sampler = sampler,
            .imageView = view,
            .imageLayout = .read_only_optimal,
        };
    }
    _ = c.FT_Done_Face(face);
    _ = c.FT_Done_FreeType(ft);
    var vals = char_map.valueIterator();
    defer while (vals.next()) |char| {
        vk.destroySampler(ctx.device, char.tex.sampler, null);
        vk.destroyImageView(ctx.device, char.tex.view, null);
        vma.destroyImage(ctx.vka, char.tex.image, char.tex.alon);
    };

    var desc_layout: vk.DescriptorSetLayout = undefined;
    defer vk.destroyDescriptorSetLayout(ctx.device, desc_layout, null);
    {
        const flags: [2]vk.DescriptorBindingFlags = .{
            .{ .partially_bound = true, .update_unused_while_pending = false },
            .{ .partially_bound = true, .update_unused_while_pending = false },
        };
        const desc_bind_flags: vk.DescriptorSetLayoutBindingFlagsCreateInfo = .{ .pBindingFlags = &flags, .bindingCount = 2 };
        const bindings = [_]vk.DescriptorSetLayoutBinding{
            .{
                .binding = 0,
                .descriptorCount = 1000,
                .descriptorType = .combined_image_sampler,
                .stageFlags = .{ .fragment = true, .compute = true },
            },
            .{
                .binding = 1,
                .descriptorCount = 100,
                .descriptorType = .storage_image,
                .stageFlags = .{ .compute = true },
            },
        };
        const desc_layout_ci: vk.DescriptorSetLayoutCreateInfo = .{
            .pNext = &desc_bind_flags,
            .pBindings = &bindings,
            .bindingCount = 2,
        };
        try vk.createDescriptorSetLayout(ctx.device, &desc_layout_ci, null, &desc_layout);
    }

    var desc_pool: vk.DescriptorPool = undefined;
    defer vk.destroyDescriptorPool(ctx.device, desc_pool, null);
    {
        const sizes: []const vk.DescriptorPoolSize = &.{
            .{ .descriptorCount = 1000, .type = .combined_image_sampler },
            .{ .descriptorCount = 100, .type = .storage_image },
        };
        const pool_ci: vk.DescriptorPoolCreateInfo = .{
            .maxSets = 2,
            .poolSizeCount = @intCast(sizes.len),
            .pPoolSizes = sizes.ptr,
        };
        try vk.createDescriptorPool(ctx.device, &pool_ci, null, &desc_pool);
    }

    var desc_set: vk.DescriptorSet = undefined;
    var writes: [2]vk.WriteDescriptorSet = undefined;
    {
        const set_ai: vk.DescriptorSetAllocateInfo = .{
            .descriptorPool = desc_pool,
            .descriptorSetCount = 1,
            .pSetLayouts = @ptrCast(&desc_layout),
        };
        try vk.allocateDescriptorSets(ctx.device, &set_ai, @ptrCast(&desc_set));
        writes = .{
            .{
                .dstSet = desc_set,
                .descriptorType = .storage_image,
                .descriptorCount = @intCast(rctx.sc_view_dsc.len),
                .dstBinding = 1,
                .pImageInfo = rctx.sc_view_dsc.ptr,
            },
            .{
                .dstSet = desc_set,
                .descriptorType = .combined_image_sampler,
                .descriptorCount = 4,
                .dstBinding = 0,
                .pImageInfo = &texture_descriptors,
            },
        };

        vk.updateDescriptorSets(ctx.device, 2, &writes, 0, undefined);
        var it = char_map.keyIterator();
        while (it.next()) |par| {
            const w: vk.WriteDescriptorSet = .{
                .dstSet = desc_set,
                .descriptorType = .combined_image_sampler,
                .descriptorCount = 1,
                .dstArrayElement = 4 + par.*,
                .dstBinding = 0,
                .pImageInfo = @ptrCast(&texture_descriptors[4 + par.*]),
            };
            vk.updateDescriptorSets(ctx.device, 1, @ptrCast(&w), 0, undefined);
        }
    }

    var pipeline_layout: vk.PipelineLayout = undefined;
    defer vk.destroyPipelineLayout(ctx.device, pipeline_layout, null);
    {
        const ci: vk.PipelineLayoutCreateInfo = .{
            .pushConstantRangeCount = shaders.shader.push_constant_ranges.len,
            .pPushConstantRanges = &shaders.shader.push_constant_ranges,
            .setLayoutCount = 1,
            .pSetLayouts = @ptrCast(&desc_layout),
        };
        try vk.createPipelineLayout(ctx.device, &ci, null, &pipeline_layout);
    }

    var blinn_module: vk.ShaderModule = undefined;
    defer vk.destroyShaderModule(ctx.device, blinn_module, null);
    {
        const module_ci: vk.ShaderModuleCreateInfo = .{ .pCode = @ptrCast(&shaders.shader.spirv), .codeSize = shaders.shader.spirv.len };
        try vk.createShaderModule(ctx.device, &module_ci, null, &blinn_module);
    }

    var pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(ctx.device, pipeline, null);
    {
        //comptime gen vertex input
        const vertex_bind: vk.VertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate = .vertex,
        };
        const vertex_attributes: [3]vk.VertexInputAttributeDescription = .{
            .{ .binding = 0, .format = .r32g32b32_sfloat, .location = 0, .offset = @offsetOf(Vertex, "pos") },
            .{ .binding = 0, .format = .r32g32b32_sfloat, .location = 1, .offset = @offsetOf(Vertex, "norm") },
            .{ .binding = 0, .format = .r32g32_sfloat, .location = 2, .offset = @offsetOf(Vertex, "uv") },
        };
        const vertex_input: vk.PipelineVertexInputStateCreateInfo = .{
            .vertexAttributeDescriptionCount = vertex_attributes.len,
            .pVertexAttributeDescriptions = &vertex_attributes,
            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = @ptrCast(&vertex_bind),
        };
        //pass in shader
        const shader_stages: [2]vk.PipelineShaderStageCreateInfo = .{
            .{ .stage = .{ .vertex = true }, .module = blinn_module, .pName = "main" },
            .{ .stage = .{ .fragment = true }, .module = blinn_module, .pName = "main" },
        };
        const render_ci: vk.PipelineRenderingCreateInfo = .{
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = @ptrCast(&rctx.sc_format),
            .depthAttachmentFormat = rctx.depth.format,
        };
        const blend_attachment: vk.PipelineColorBlendAttachmentState = .{ .colorWriteMask = @bitCast(@as(u32, 0xF)) };
        var ci: vk.GraphicsPipelineCreateInfo = .{
            .pNext = &render_ci,
            .stageCount = 2,
            .pStages = &shader_stages,
            .pVertexInputState = &vertex_input,
            .pInputAssemblyState = &.{ .topology = .triangle_list },
            .pViewportState = &.{ .viewportCount = 1, .scissorCount = 1 },
            .pRasterizationState = &.{ .lineWidth = 1.0, .polygonMode = .fill, .cullMode = .{ .back = true } },
            .pMultisampleState = &.{ .rasterizationSamples = .{ .@"1" = true } },
            .pDepthStencilState = &.{ .depthTestEnable = .True, .depthWriteEnable = .True, .depthCompareOp = .less_or_equal },
            .pColorBlendState = &.{ .attachmentCount = 1, .pAttachments = @ptrCast(&blend_attachment) },
            .pDynamicState = &.{ .dynamicStateCount = 2, .pDynamicStates = &.{ .viewport, .scissor } },
            .layout = pipeline_layout,
        };

        try vk.createGraphicsPipelines(ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&pipeline));
    }

    var skybox_module: vk.ShaderModule = undefined;
    defer vk.destroyShaderModule(ctx.device, skybox_module, null);
    {
        const ci: vk.ShaderModuleCreateInfo = .{
            .codeSize = shaders.skybox.spirv.len,
            .pCode = @ptrCast(&shaders.skybox.spirv),
        };
        try vk.createShaderModule(ctx.device, &ci, null, &skybox_module);
    }

    var skybox_pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(ctx.device, skybox_pipeline, null);
    {
        const bind: vk.VertexInputBindingDescription = .{
            .binding = 0,
            .inputRate = .vertex,
            .stride = @sizeOf(Vertex),
        };
        const attribute: vk.VertexInputAttributeDescription = .{
            .binding = 0,
            .format = .r32g32b32_sfloat,
            .location = 0,
            .offset = 0,
        };
        const vci: vk.PipelineVertexInputStateCreateInfo = .{
            .vertexAttributeDescriptionCount = 1,
            .pVertexAttributeDescriptions = @ptrCast(&attribute),
            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = @ptrCast(&bind),
        };
        const stages: [2]vk.PipelineShaderStageCreateInfo = .{
            .{ .module = skybox_module, .pName = "main", .stage = .{ .vertex = true } },
            .{ .module = skybox_module, .pName = "main", .stage = .{ .fragment = true } },
        };
        const render_ci: vk.PipelineRenderingCreateInfo = .{
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = @ptrCast(&rctx.sc_format),
            .depthAttachmentFormat = rctx.depth.format,
        };
        const blend_attachment: vk.PipelineColorBlendAttachmentState = .{ .colorWriteMask = @bitCast(@as(u32, 0xF)) };
        var ci: vk.GraphicsPipelineCreateInfo = .{
            .pNext = &render_ci,
            .stageCount = stages.len,
            .pStages = &stages,
            .pVertexInputState = &vci,
            .pInputAssemblyState = &.{ .topology = .triangle_list },
            .pViewportState = &.{ .viewportCount = 1, .scissorCount = 1 },
            .pRasterizationState = &.{ .lineWidth = 1.0, .polygonMode = .fill, .cullMode = .{ .front = true } },
            .pMultisampleState = &.{ .rasterizationSamples = .{ .@"1" = true } },
            .pDepthStencilState = &.{ .depthTestEnable = .True, .depthWriteEnable = .True, .depthCompareOp = .equal },
            .pColorBlendState = &.{ .attachmentCount = 1, .pAttachments = @ptrCast(&blend_attachment) },
            .pDynamicState = &.{ .dynamicStateCount = 2, .pDynamicStates = &.{ .viewport, .scissor } },
            .layout = pipeline_layout,
        };
        try vk.createGraphicsPipelines(ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&skybox_pipeline));
    }

    var text_module: vk.ShaderModule = undefined;
    defer vk.destroyShaderModule(ctx.device, text_module, null);
    {
        const ci: vk.ShaderModuleCreateInfo = .{
            .codeSize = shaders.text.spirv.len,
            .pCode = @ptrCast(&shaders.text.spirv),
        };
        try vk.createShaderModule(ctx.device, &ci, null, &text_module);
    }

    var text_pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(ctx.device, text_pipeline, null);
    {
        const bind: vk.VertexInputBindingDescription = .{
            .binding = 0,
            .inputRate = .vertex,
            .stride = @sizeOf(f32) * 4,
        };
        const attribute: vk.VertexInputAttributeDescription = .{
            .binding = 0,
            .format = .r32g32b32a32_sfloat,
            .location = 0,
            .offset = 0,
        };
        const vci: vk.PipelineVertexInputStateCreateInfo = .{
            .vertexAttributeDescriptionCount = 1,
            .pVertexAttributeDescriptions = @ptrCast(&attribute),
            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = @ptrCast(&bind),
        };
        const stages: [2]vk.PipelineShaderStageCreateInfo = .{
            .{ .module = text_module, .pName = "main", .stage = .{ .vertex = true } },
            .{ .module = text_module, .pName = "main", .stage = .{ .fragment = true } },
        };
        const render_ci: vk.PipelineRenderingCreateInfo = .{
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = @ptrCast(&rctx.sc_format),
            .depthAttachmentFormat = .d32_sfloat_s8_uint,
        };
        const blend_attachment: vk.PipelineColorBlendAttachmentState = .{
            .blendEnable = .True,
            .colorBlendOp = .add,
            .srcColorBlendFactor = .src_alpha,
            .dstColorBlendFactor = .one_minus_src_alpha,
            .colorWriteMask = @bitCast(@as(u32, 0xF)),
        };
        var ci: vk.GraphicsPipelineCreateInfo = .{
            .pNext = &render_ci,
            .stageCount = stages.len,
            .pStages = &stages,
            .pVertexInputState = &vci,
            .pInputAssemblyState = &.{ .topology = .triangle_list },
            .pViewportState = &.{ .viewportCount = 1, .scissorCount = 1 },
            .pRasterizationState = &.{ .lineWidth = 1.0, .polygonMode = .fill, .cullMode = .{} },
            .pMultisampleState = &.{ .rasterizationSamples = .{ .@"1" = true } },
            .pDepthStencilState = &.{ .depthTestEnable = .True, .depthCompareOp = .always },
            .pColorBlendState = &.{ .attachmentCount = 1, .pAttachments = @ptrCast(&blend_attachment) },
            .pDynamicState = &.{ .dynamicStateCount = 2, .pDynamicStates = &.{ .viewport, .scissor } },
            .layout = pipeline_layout,
        };
        try vk.createGraphicsPipelines(ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&text_pipeline));
    }

    var post_layout: vk.PipelineLayout = undefined;
    defer vk.destroyPipelineLayout(ctx.device, post_layout, null);
    {
        const ci: vk.PipelineLayoutCreateInfo = .{
            .setLayoutCount = 1,
            .pSetLayouts = @ptrCast(&desc_layout),
            .pushConstantRangeCount = shaders.box.push_constant_ranges.len,
            .pPushConstantRanges = @ptrCast(&shaders.box.push_constant_ranges),
        };
        try vk.createPipelineLayout(ctx.device, &ci, null, &post_layout);
    }

    var box_module: vk.ShaderModule = undefined;
    defer vk.destroyShaderModule(ctx.device, box_module, null);
    {
        const ci: vk.ShaderModuleCreateInfo = .{
            .codeSize = shaders.box.spirv.len,
            .pCode = @ptrCast(&shaders.box.spirv),
        };
        try vk.createShaderModule(ctx.device, &ci, null, &box_module);
    }

    var boxblur_pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(ctx.device, boxblur_pipeline, null);
    {
        const ci: vk.ComputePipelineCreateInfo = .{
            .layout = post_layout,
            .stage = .{ .stage = .{ .compute = true }, .module = box_module, .pName = "main" },
        };
        try vk.createComputePipelines(ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&boxblur_pipeline));
    }

    var shader_buffers: [max_frames]zkf.Buffer = undefined;
    defer for (shader_buffers) |buffer| {
        buffer.deinit(ctx.vka);
    };
    for (0..max_frames) |i| {
        const uBufferCI: vk.BufferCreateInfo = .{
            .size = @sizeOf(ShaderData),
            .usage = .{ .shader_device_address = true },
        };
        shader_buffers[i] = .init(ctx.vka, uBufferCI, .mapped_vram);
    }

    //basic dt and quit
    var last_time = Io.Clock.now(.real, io).toMicroseconds();
    var quit: bool = false;

    //sync stuff that really should be part of swapchain
    var recreate_swap: bool = false;
    var swapchain_index: u32 = 0;
    var fif_index: usize = 0;
    var frame: u64 = 0;
    var signal_val: [max_frames]u64 = @splat(0);

    //"game stuff"
    var shader_data: ShaderData = .{};
    var sel: u32 = 0;

    //some stats
    var frametime_acc: f32 = 0;
    const frametime_goal = 8333;
    var diff_acc: f32 = 0;

    while (!quit) {
        const wait_info: vk.SemaphoreWaitInfo = .{ .semaphoreCount = 1, .pSemaphores = @ptrCast(&rctx.loop_tml), .pValues = &.{signal_val[fif_index]} };
        try vk.waitSemaphores(ctx.device, &wait_info, std.math.maxInt(u64));
        frame += 1;
        vk.acquireNextImageKHR(ctx.device, rctx.swapchain, std.math.maxInt(u64), rctx.fif_semaphore[fif_index], null, &swapchain_index) catch |e| switch (e) {
            error.error_out_of_dateKHR, error.suboptimalKHR => recreate_swap = true,
            else => return e,
        };

        //reduces input latency or smth
        // try Io.sleep(io, .fromMicroseconds(7000), .real);

        const elasped: f32 = @floatFromInt(Io.Clock.now(.real, io).toMicroseconds() - last_time);
        last_time = Io.Clock.now(.real, io).toMicroseconds();
        const dT = elasped / 1000000.0;

        frametime_acc += elasped;
        diff_acc += @abs(frametime_goal - elasped);

        //input
        {
            if (mouse_mode) {
                var xrel: f32 = 0;
                var yrel: f32 = 0;
                mouse_state = sdl.getRelativeMouseState(&xrel, &yrel);
                cam.mouseInput(xrel, yrel);
            } else {
                mouse_state = sdl.getMouseState(&mouse_pos.x, &mouse_pos.y);
            }

            const keyboard_state = sdl.getKeyboardState(null);
            var in: [4]bool = @splat(false);
            if (keyboard_state[@intFromEnum(sdl.Scancode.w)]) {
                in[0] = true;
            }
            if (keyboard_state[@intFromEnum(sdl.Scancode.s)]) {
                in[1] = true;
            }
            if (keyboard_state[@intFromEnum(sdl.Scancode.d)]) {
                in[2] = true;
            }
            if (keyboard_state[@intFromEnum(sdl.Scancode.a)]) {
                in[3] = true;
            }

            cam.moveInput(dT, in);

            var event: sdl.Event = undefined;
            while (sdl.pollEvent(&event)) {
                switch (event.type) {
                    .quit => quit = true,
                    .window_resized => recreate_swap = true,
                    .key_down => {
                        if (!event.key.repeat) {
                            switch (event.key.scancode) {
                                .h => sel = (sel + 1) % 3,
                                .escape => quit = true,
                                .f11 => {
                                    fullscreen = !fullscreen;
                                    _ = sdl.setWindowFullscreen(rctx.window, fullscreen);
                                },
                                .f10 => {
                                    mouse_mode = !mouse_mode;
                                    _ = sdl.setWindowRelativeMouseMode(rctx.window, mouse_mode);
                                },
                                else => {},
                            }
                        }
                    },
                    else => {},
                }
            }
        }

        const aspect = @as(f32, @floatFromInt(rctx.windowsize.width)) / @as(f32, @floatFromInt(rctx.windowsize.height));

        shader_data.projection = .perspective(cam.fov, aspect, 0.1, 32.0);
        shader_data.ortho = .ortho(0.0, @floatFromInt(rctx.windowsize.width), 0.0, @floatFromInt(rctx.windowsize.height));
        shader_data.cam = cam.pose;
        shader_data.selected = sel;
        for ((&shader_data.poses)[0..3], 0..) |*pose, i| {
            const idx: f32 = @floatFromInt(i);
            const pos: Vec3 = .{ .x = (idx - 1.0) * 3.0, .y = -(idx), .z = 0.0 };
            const lookup: [4]Vec3 = .{
                Vec3{ .z = @sin(dT) },
                Vec3{ .z = 1 },
                Vec3{ .x = 1 },
                Vec3{ .x = -1 },
            };

            pose.pos = pos;
            pose.extra = 1.0;
            pose.rot = pose.rot.mul(.fromAngleAxis(std.math.pi * 0.5 * dT, lookup[i])).normalize();
        }
        shader_data.poses[4].pos = .{ .z = -2 };

        shader_buffers[fif_index].write(0, shader_data);

        const cb: vk.CommandBuffer = command_buffers[fif_index];
        try vk.resetCommandBuffer(cb, .{});

        {
            try vk.beginCommandBuffer(cb, &.{ .flags = .{ .one_time_submit = true } });

            const output_barriers: [2]vk.ImageMemoryBarrier2 = .{ .{
                .srcStageMask = .{ .compute_shader = true, .color_attachment_output = true },
                .srcAccessMask = .{},
                .dstStageMask = .{ .color_attachment_output = true },
                .dstAccessMask = .{ .color_attachment_read = true, .color_attachment_write = true },
                .oldLayout = .undefined,
                .newLayout = .attachment_optimal,
                .image = rctx.sc_imgs[swapchain_index],
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .levelCount = 1, .layerCount = 1 },
            }, .{
                .srcStageMask = .{ .late_fragment_tests = true },
                .srcAccessMask = .{ .depth_stencil_attachment_write = true },
                .dstStageMask = .{ .early_fragment_tests = true },
                .dstAccessMask = .{ .depth_stencil_attachment_write = true },
                .oldLayout = .undefined,
                .newLayout = .attachment_optimal,
                .image = rctx.depth.handle,
                .subresourceRange = .{ .aspectMask = .{ .depth = true, .stencil = true }, .levelCount = 1, .layerCount = 1 },
            } };
            vk.cmdPipelineBarrier2(cb, &.{ .imageMemoryBarrierCount = 2, .pImageMemoryBarriers = &output_barriers });

            const color_attach_info: vk.RenderingAttachmentInfo = .{
                .imageView = rctx.sc_img_views[swapchain_index],
                .imageLayout = .attachment_optimal,
                .loadOp = .clear,
                .storeOp = .store,
                .clearValue = .{ .color = .{ .float32 = .{ 0.0, 0.0, 0.0, 1.0 } } },
            };
            const depth_attach_info: vk.RenderingAttachmentInfo = .{
                .imageView = rctx.depth.view,
                .imageLayout = .attachment_optimal,
                .loadOp = .clear,
                .storeOp = .dont_care,
                .clearValue = .{ .depthStencil = .{ .depth = 1.0, .stencil = 0 } },
            };

            const rendering_info: vk.RenderingInfo = .{
                .renderArea = .{ .extent = rctx.windowsize },
                .layerCount = 1,
                .colorAttachmentCount = 1,
                .pColorAttachments = @ptrCast(&color_attach_info),
                .pDepthAttachment = &depth_attach_info,
            };

            {
                vk.cmdBeginRendering(cb, &rendering_info);
                defer vk.cmdEndRendering(cb);
                const vp: vk.Viewport = .{
                    .width = @floatFromInt(rctx.windowsize.width),
                    .height = @floatFromInt(rctx.windowsize.height),
                    .maxDepth = 1.0,
                    .minDepth = 0.0,
                };
                vk.cmdSetViewport(cb, 0, 1, @ptrCast(&vp));
                const scissor: vk.Rect2D = .{ .extent = rctx.windowsize };
                vk.cmdSetScissor(cb, 0, 1, @ptrCast(&scissor));

                vk.cmdBindPipeline(cb, .graphics, pipeline);
                vk.cmdBindDescriptorSets(cb, .graphics, pipeline_layout, 0, 1, @ptrCast(&desc_set), 0, undefined);
                vk.cmdPushConstants(cb, pipeline_layout, .{ .vertex = true }, 0, @sizeOf(vk.DeviceAddress), std.mem.asBytes(&shader_buffers[fif_index].address(ctx.device)));

                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&suzanne_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, suzanne_buffer.handle, vBufferSize, .uint32);
                vk.cmdDrawIndexed(cb, @intCast(suzanne.indices.items.len), 3, 0, 0, 0);

                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&plane_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, plane_buffer.handle, @sizeOf(f32) * plane_vertices.len, .uint16);
                vk.cmdDrawIndexed(cb, @intCast(quad_indices.len), 1, 0, 0, 3);

                vk.cmdBindPipeline(cb, .graphics, skybox_pipeline);
                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&cube_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, cube_buffer.handle, @sizeOf(Vertex) * cube.vertices.items.len, .uint32);
                vk.cmdDrawIndexed(cb, @intCast(cube.indices.items.len), 1, 0, 0, 0);

                vk.cmdBindPipeline(cb, .graphics, text_pipeline);
                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&text_quad.handle), &.{0});
                const text = try std.fmt.allocPrint(arena, "frametime: {d:.3}", .{elasped / 1000});

                var pos: Vec2 = .{ .x = 50, .y = 102 };
                const scale: f32 = 0.9;
                for (text, 0..) |char, i| {
                    if (char == ' ') {
                        pos.x += @floatFromInt(space_advance >> 6);
                        continue;
                    }
                    const ch = char_map.get(char) orelse continue;
                    const charpos: Vec2 = .{
                        .x = pos.x + @as(f32, @floatFromInt(ch.bearingx)) * scale,
                        .y = pos.y + @as(f32, @floatFromInt(@as(i32, @intCast(ch.height)) - ch.bearingy)) * scale,
                    };

                    const w: f32 = @as(f32, @floatFromInt(ch.width)) * scale;
                    const h: f32 = @as(f32, @floatFromInt(ch.height)) * scale;
                    const vertices = [_]f32{
                        charpos.x,     charpos.y - h, 0.0, 0.0,
                        charpos.x,     charpos.y,     0.0, 1.0,
                        charpos.x + w, charpos.y,     1.0, 1.0,
                        charpos.x,     charpos.y - h, 0.0, 0.0,
                        charpos.x + w, charpos.y,     1.0, 1.0,
                        charpos.x + w, charpos.y - h, 1.0, 0.0,
                    };
                    text_quad.write(quad_size * i, &vertices);
                    vk.cmdDraw(cb, 6, 1, @intCast(i * 6), char);
                    pos.x += @as(f32, @floatFromInt(ch.advance >> 6)) * scale;
                }
            }
            vk.cmdBindDescriptorSets(cb, .compute, post_layout, 0, 1, @ptrCast(&desc_set), 0, undefined);
            vk.cmdPushConstants(cb, post_layout, .{ .compute = true }, 0, 8, @ptrCast(&mouse_pos));
            vk.cmdPushConstants(cb, post_layout, .{ .compute = true }, 8, 4, @ptrCast(&swapchain_index));
            const compute_barrier1: vk.ImageMemoryBarrier2 = .{
                .srcStageMask = .{ .color_attachment_output = true },
                .srcAccessMask = .{ .color_attachment_write = true },
                .dstStageMask = .{ .compute_shader = true },
                .dstAccessMask = .{ .shader_storage_read = true, .shader_storage_write = true },
                .oldLayout = .attachment_optimal,
                .newLayout = .general,
                .image = rctx.sc_imgs[swapchain_index],
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
            };
            vk.cmdPipelineBarrier2(cb, &.{ .imageMemoryBarrierCount = 1, .pImageMemoryBarriers = @ptrCast(&compute_barrier1) });

            vk.cmdBindPipeline(cb, .compute, boxblur_pipeline);
            vk.cmdDispatch(cb, (rctx.windowsize.width / shaders.box.local_size[0]) + 1, (rctx.windowsize.height / shaders.box.local_size[1]) + 1, 1);

            const compute_barrier2: vk.ImageMemoryBarrier2 = .{
                .srcStageMask = .{ .compute_shader = true },
                .srcAccessMask = .{ .shader_storage_write = true },
                .dstStageMask = .{ .compute_shader = true },
                .dstAccessMask = .{ .shader_storage_read = true, .shader_storage_write = true },
                .oldLayout = .general,
                .newLayout = .general,
                .image = rctx.sc_imgs[swapchain_index],
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
            };
            vk.cmdPipelineBarrier2(cb, &.{ .imageMemoryBarrierCount = 1, .pImageMemoryBarriers = @ptrCast(&compute_barrier2) });

            // const present_barrier: vk.ImageMemoryBarrier2 = .{
            //     .srcStageMask = .{ .color_attachment_output = true },
            //     .srcAccessMask = .{ .color_attachment_write = true },
            //     .dstStageMask = .{ .color_attachment_output = true },
            //     .dstAccessMask = .{},
            //     .oldLayout = .attachment_optimal,
            //     .newLayout = .present_srcKHR,
            //     .image = rctx.sc_imgs[swapchain_index],
            //     .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
            // };
            const present_barrier: vk.ImageMemoryBarrier2 = .{
                .srcStageMask = .{ .compute_shader = true },
                .srcAccessMask = .{ .shader_storage_write = true },
                .dstStageMask = .{ .compute_shader = true },
                .dstAccessMask = .{},
                .oldLayout = .general,
                .newLayout = .present_srcKHR,
                .image = rctx.sc_imgs[swapchain_index],
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
            };

            vk.cmdPipelineBarrier2(cb, &.{
                .imageMemoryBarrierCount = 1,
                .pImageMemoryBarriers = @ptrCast(&present_barrier),
            });

            try vk.endCommandBuffer(cb);
        }

        const present_signal: vk.SemaphoreSubmitInfo = .{ .semaphore = rctx.swapchain_semaphore[swapchain_index], .stageMask = .{ .compute_shader = true } };
        const loop_signal: vk.SemaphoreSubmitInfo = .{ .semaphore = rctx.loop_tml, .stageMask = .{ .compute_shader = true }, .value = frame };
        const submit_info2: vk.SubmitInfo2 = .{
            .waitSemaphoreInfoCount = 1,
            .pWaitSemaphoreInfos = &.{.{ .semaphore = rctx.fif_semaphore[fif_index], .stageMask = .{ .color_attachment_output = true } }},
            .commandBufferInfoCount = 1,
            .pCommandBufferInfos = &.{.{ .commandBuffer = cb }},
            .signalSemaphoreInfoCount = 2,
            .pSignalSemaphoreInfos = &.{ present_signal, loop_signal },
        };
        try vk.queueSubmit2(ctx.queue, 1, @ptrCast(&submit_info2), null);
        signal_val[fif_index] = frame;
        fif_index = (fif_index + 1) % max_frames;

        const present_info: vk.PresentInfoKHR = .{
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = @ptrCast(&rctx.swapchain_semaphore[swapchain_index]),
            .swapchainCount = 1,
            .pSwapchains = @ptrCast(&rctx.swapchain),
            .pImageIndices = @ptrCast(&swapchain_index),
        };

        vk.queuePresentKHR(ctx.queue, &present_info) catch |e| switch (e) {
            error.error_out_of_dateKHR, error.suboptimalKHR => recreate_swap = true,
            else => return e,
        };

        if (recreate_swap) {
            recreate_swap = false;
            try rctx.recreate_swap(&ctx);
            vk.updateDescriptorSets(ctx.device, 1, @ptrCast(&writes[0]), 0, undefined);
        }
    }

    try vk.deviceWaitIdle(ctx.device);
    const fframe: f32 = @floatFromInt(frame);
    log.info("avg_framtime: {}\tavg_diff from {}: {}", .{ frametime_acc / fframe, frametime_goal, diff_acc / fframe });
}

const quad_indices: [6]u16 = .{
    0, 1, 2,
    2, 3, 0,
};

const plane_vertices: [32]f32 = .{
    -10.0, 2.0, 10.0,  0.0, 1.0, 0.0, 0.0, 1.0,
    10.0,  2.0, 10.0,  0.0, 1.0, 0.0, 1.0, 1.0,
    10.0,  2.0, -10.0, 0.0, 1.0, 0.0, 1.0, 0.0,
    -10.0, 2.0, -10.0, 0.0, 1.0, 0.0, 0.0, 0.0,
};
