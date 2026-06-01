const std = @import("std");
const log = std.log.scoped(.howtovulkan);
const Io = std.Io;

const vk = @import("vk");
const shaders = @import("shaders");
const gltf = @import("zgltf").Gltf;

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

pub const Scene = extern struct {
    projection: Mat4 = .zero,
    ortho: Mat4 = .zero,
    cam: Pose = .{},
    light_pos: Vec4 = .{ .x = 0.0, .y = -4.0, .z = 3.0, .w = 0.0 },
    selected: u32 = 1,
};

const Glyph = struct {
    uv: Vec2 = .{},
    uv_max: Vec2 = .{},
    bearing: Vec2 = .{},
    scale: Vec2 = .{},
    advance: f32 = 0,
};
var charmap: std.AutoHashMapUnmanaged(u21, Glyph) = .empty;

const Thingies = struct {
    model_idx: usize,
    position: Vec3,
};

const SceneZon = struct {
    entities: []const Thingies,
    models: []const []const u8,
    skybox: []const u8,
};

const max_frames = 2;
var cam: Camera = .{ .pose = .{ .pos = .{ .z = 6.0 }, .rot = .identity, .extra = 0 } };
var fullscreen = false;

var mouse_mode = true;
var mouse_pos: Vec2 = .{ .x = 0, .y = 0 };
var mouse_state: sdl.MouseButtonFlags = .{};

var space_advance: f32 = undefined;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    var io = init.io;
    const a_static = init.arena.allocator();
    var arena_startup = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const a_startup = arena_startup.allocator();
    var arena_frame = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const a_frame = arena_frame.allocator();

    var ctx: zkf.Context = try .init(a_startup);
    defer ctx.deinit();

    var asset: zkf.AssetManager = try .init(ctx, gpa);
    defer asset.deinit(ctx, gpa);

    var rctx: zkf.RenderContext = try .init(&ctx, a_static, 1920, 1080, "testing", max_frames, &asset);
    defer rctx.deinit(&ctx, &asset);

    var commandPool: vk.CommandPool = undefined;
    var command_buffers: [max_frames]vk.CommandBuffer = undefined;
    defer vk.destroyCommandPool(ctx.device, commandPool, null);
    {
        const commandPoolCI: vk.CommandPoolCreateInfo = .{ .flags = .{ .reset_command_buffer = true }, .queueFamilyIndex = ctx.qfamily };
        try vk.createCommandPool(ctx.device, &commandPoolCI, null, &commandPool);
        const cmdBufferCI: vk.CommandBufferAllocateInfo = .{ .commandPool = commandPool, .commandBufferCount = max_frames, .level = .primary };
        try vk.allocateCommandBuffers(ctx.device, &cmdBufferCI, &command_buffers);
    }

    _ = sdl.setWindowRelativeMouseMode(rctx.window, true);

    const suzanne = try zkf.loadObj(a_static, &io, "assets/suzanne.obj");
    const cube = try zkf.loadObj(a_static, &io, "assets/cube.obj");

    const vBufferSize: vk.DeviceSize = @sizeOf(Vertex) * suzanne.vertices.items.len;
    const iBufferSize: vk.DeviceSize = @sizeOf(u32) * suzanne.indices.items.len;
    const suzanne_buffer = try zkf.Buffer.init(ctx.vka, .{ .size = vBufferSize + iBufferSize, .usage = .{ .index_buffer = true, .vertex_buffer = true } }, .mapped_vram);
    defer suzanne_buffer.deinit(ctx.vka);
    suzanne_buffer.write(0, suzanne.vertices.items);
    suzanne_buffer.write(vBufferSize, suzanne.indices.items);

    const cube_buffer = try zkf.Buffer.init(ctx.vka, .{
        .size = @sizeOf(Vertex) * cube.vertices.items.len + @sizeOf(u32) * cube.indices.items.len,
        .usage = .{ .index_buffer = true, .vertex_buffer = true },
    }, .mapped_vram);
    defer cube_buffer.deinit(ctx.vka);
    cube_buffer.write(0, cube.vertices.items);
    cube_buffer.write(@sizeOf(Vertex) * cube.vertices.items.len, cube.indices.items);

    const plane_buffer = try zkf.Buffer.init(ctx.vka, .{
        .size = @sizeOf(f32) * plane_vertices.len + @sizeOf(u32) * quad_indices.len,
        .usage = .{ .index_buffer = true, .vertex_buffer = true },
    }, .mapped_vram);
    defer plane_buffer.deinit(ctx.vka);
    plane_buffer.write(0, plane_vertices);
    plane_buffer.write(@sizeOf(f32) * plane_vertices.len, quad_indices);

    const quad_size = @sizeOf(f32) * 6 * 4;
    const text_quad = try zkf.Buffer.init(ctx.vka, .{
        .size = quad_size * 100,
        .usage = .{ .vertex_buffer = true },
    }, .mapped_vram);
    defer text_quad.deinit(ctx.vka);

    //textures

    //loading scene
    const helm = try asset.loadGltf(&ctx, io, gpa, commandPool, "assets/helm/DamagedHelmet.gltf");
    // defer {
    //     asset.freeSampledImage(&ctx, helm.material.albedo);
    //     asset.freeSampledImage(&ctx, helm.material.metallic_roughness);
    //     asset.freeSampledImage(&ctx, helm.material.normal);
    //     asset.freeSampledImage(&ctx, helm.material.occlusion);
    //     asset.freeSampledImage(&ctx, helm.material.emissive);
    //     for (helm.images) |image| {
    //         asset.freeImage(&ctx, image);
    //     }
    // }

    var handles: [3]zkf.AssetManager.Hate = undefined;
    defer for (handles) |handle| {
        asset.popHate(&ctx, handle);
    };
    for (0..3) |i| {
        var buf: [128]u8 = @splat(0);
        const filename = try std.fmt.bufPrintSentinel(&buf, "assets/suzanne{}.ktx2", .{i}, 0);
        handles[i] = try asset.loadTexture(&ctx, gpa, commandPool, filename);
    }

    const handle2 = try asset.loadTexture(&ctx, gpa, commandPool, "assets/skybox.ktx2");
    defer asset.popHate(&ctx, handle2);

    const helm_tex = try asset.loadTexture(&ctx, gpa, commandPool, "assets/helm/albedo.ktx2");
    defer asset.popHate(&ctx, helm_tex);

    //fonts
    var ft: c.FT_Library = undefined;
    if (c.FT_Init_FreeType(&ft) != 0) {
        log.info("Failed to init freetype.", .{});
        return error.Freetype;
    }
    var face: c.FT_Face = undefined;
    if (c.FT_New_Face(ft, "/usr/share/fonts/ibm-plex-sans-fonts/IBMPlexSans-Text.otf", 0, &face) != 0) {
        log.info("Failed to init face", .{});
        return error.Face;
    }
    const font_size = 32;
    if (c.FT_Set_Pixel_Sizes(face, 0, font_size) != 0) @panic("");

    const atlas_size = 1024;
    var atlas_offsetx: u32 = 0;
    var atlas_offsety: u32 = 0;
    const atlas_ci: vk.ImageCreateInfo = .{
        .imageType = .@"2d",
        .format = .r8_unorm,
        .extent = .{ .width = atlas_size, .height = atlas_size, .depth = 1 },
        .samples = .{ .@"1" = true },
        .usage = .{ .transfer_dst = true, .sampled = true },
        .mipLevels = 1,
        .arrayLayers = 1,
    };
    const font_atlas = try asset.allocImage(&ctx, atlas_ci);
    defer asset.freeImage(&ctx, font_atlas);
    try vk.nameHandle(ctx.device, asset.getImage(font_atlas), "Font Atlas");

    const atlas_view_ci: vk.ImageViewCreateInfo = .{
        .format = .r8_unorm,
        .image = asset.getImage(font_atlas),
        .viewType = .@"2d",
        .subresourceRange = .{
            .aspectMask = .{ .color = true },
            .layerCount = 1,
            .levelCount = 1,
        },
    };
    const atlas_view = try asset.allocSampledImage(&ctx, atlas_view_ci);
    defer asset.freeSampledImage(&ctx, atlas_view);

    const semaphore_type: vk.SemaphoreTypeCreateInfo = .{ .semaphoreType = .timeline };
    const semaphore_ci: vk.SemaphoreCreateInfo = .{ .pNext = &semaphore_type };
    var upload_semaphore: vk.Semaphore = undefined;
    try vk.createSemaphore(ctx.device, &semaphore_ci, null, &upload_semaphore);
    defer vk.destroySemaphore(ctx.device, upload_semaphore, null);
    var upload_count: u64 = 0;

    const glyph_size = font_size * font_size;
    const transfer_buffer_size = 5;
    const transfer_ci: vk.BufferCreateInfo = .{ .size = glyph_size * transfer_buffer_size, .usage = .{ .transfer_src = true } };
    const transfer_buffer: zkf.Buffer = try .init(ctx.vka, transfer_ci, .mapped_vram);
    defer transfer_buffer.deinit(ctx.vka);

    var cmd_buf: vk.CommandBuffer = undefined;
    const cmd_buf_ai: vk.CommandBufferAllocateInfo = .{ .commandPool = commandPool, .commandBufferCount = 1, .level = .primary };
    try vk.allocateCommandBuffers(ctx.device, &cmd_buf_ai, @ptrCast(&cmd_buf));
    defer vk.freeCommandBuffers(ctx.device, commandPool, 1, @ptrCast(&cmd_buf));
    const cmd_binfo: vk.CommandBufferBeginInfo = .{ .flags = .{ .one_time_submit = true } };

    var transfer_offset: u32 = 0;

    {
        try vk.beginCommandBuffer(cmd_buf, &cmd_binfo);
        var layout_barrier: vk.ImageMemoryBarrier2 = .{
            .dstStageMask = .{ .all_transfer = true },
            .dstAccessMask = .{ .transfer_write = true },
            .oldLayout = .undefined,
            .newLayout = .transfer_dst_optimal,
            .image = asset.getImage(font_atlas),
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
    }

    for (31..128) |i| {
        if (c.FT_Load_Char(face, i, c.FT_LOAD_RENDER) != 0) {
            log.info("failed to load {c}", .{@as(u8, @intCast(i))});
            continue;
        }
        const glyph = face.*.glyph.*;
        if (i == ' ') {
            space_advance = @floatFromInt(glyph.advance.x >> 6);
            continue;
        }

        var out: Glyph = .{
            .bearing = .{ .x = @floatFromInt(glyph.bitmap_left), .y = @floatFromInt(-glyph.bitmap_top) },
            .advance = @floatFromInt(glyph.advance.x >> 6),
        };

        transfer_buffer.write(transfer_offset * glyph_size, glyph.bitmap.buffer[0 .. glyph.bitmap.rows * glyph.bitmap.width]);

        {
            if (atlas_offsetx + glyph.bitmap.width >= atlas_size) {
                atlas_offsety += font_size;
                atlas_offsetx = 0;
            }
            const copy_test: vk.BufferImageCopy = .{
                .imageSubresource = .{
                    .aspectMask = .{ .color = true },
                    .layerCount = 1,
                },
                .imageExtent = .{
                    .depth = 1,
                    .width = glyph.bitmap.width,
                    .height = glyph.bitmap.rows,
                },
                .imageOffset = .{
                    .x = @intCast(atlas_offsetx),
                    .y = @intCast(atlas_offsety),
                },
                .bufferOffset = transfer_offset * glyph_size,
            };
            vk.cmdCopyBufferToImage(cmd_buf, transfer_buffer.handle, asset.getImage(font_atlas), .transfer_dst_optimal, 1, &.{copy_test});
            transfer_offset += 1;

            out.uv = .{
                .x = @as(f32, @floatFromInt(atlas_offsetx)) / atlas_size,
                .y = @as(f32, @floatFromInt(atlas_offsety)) / atlas_size,
            };
            out.uv_max = .{
                .x = @as(f32, @floatFromInt(atlas_offsetx + glyph.bitmap.width)) / atlas_size,
                .y = @as(f32, @floatFromInt(atlas_offsety + glyph.bitmap.rows)) / atlas_size,
            };
            const yscale = @as(f32, @floatFromInt(glyph.bitmap.rows));
            atlas_offsetx += glyph.bitmap.width + 2;
            const ratio = (out.uv_max.x - out.uv.x) / (out.uv_max.y - out.uv.y);
            out.scale = .{ .x = ratio * yscale, .y = yscale };
            try charmap.put(a_static, @intCast(i), out);

            if (transfer_offset == 5) {
                try vk.endCommandBuffer(cmd_buf);
                const smp_submit: vk.SemaphoreSubmitInfo = .{
                    .semaphore = upload_semaphore,
                    .stageMask = .{ .all_transfer = true },
                    .value = upload_count + 1,
                };
                const submiti: vk.SubmitInfo2 = .{
                    .commandBufferInfoCount = 1,
                    .pCommandBufferInfos = &.{.{ .commandBuffer = cmd_buf }},
                    .signalSemaphoreInfoCount = 1,
                    .pSignalSemaphoreInfos = &.{smp_submit},
                };
                try vk.queueSubmit2(ctx.queue, 1, &.{submiti}, null);
                const waiti: vk.SemaphoreWaitInfo = .{
                    .semaphoreCount = 1,
                    .pSemaphores = @ptrCast(&upload_semaphore),
                    .pValues = &.{upload_count + 1},
                };
                try vk.waitSemaphores(ctx.device, &waiti, std.math.maxInt(u64));
                upload_count += 1;

                try vk.beginCommandBuffer(cmd_buf, &cmd_binfo);

                transfer_offset = 0;
            }
        }
    }
    var layout_barrier: vk.ImageMemoryBarrier2 = .{
        .srcStageMask = .{ .all_transfer = true },
        .srcAccessMask = .{ .transfer_write = true },
        .oldLayout = .transfer_dst_optimal,
        .newLayout = .read_only_optimal,
        .image = asset.getImage(font_atlas),
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
    try vk.endCommandBuffer(cmd_buf);
    const smp_submit: vk.SemaphoreSubmitInfo = .{
        .semaphore = upload_semaphore,
        .value = upload_count + 1,
    };
    const submiti: vk.SubmitInfo2 = .{
        .commandBufferInfoCount = 1,
        .pCommandBufferInfos = &.{.{ .commandBuffer = cmd_buf }},
        .signalSemaphoreInfoCount = 1,
        .pSignalSemaphoreInfos = &.{smp_submit},
    };
    try vk.queueSubmit2(ctx.queue, 1, &.{submiti}, null);
    const waiti: vk.SemaphoreWaitInfo = .{
        .semaphoreCount = 1,
        .pSemaphores = @ptrCast(&upload_semaphore),
        .pValues = &.{upload_count + 1},
    };
    try vk.waitSemaphores(ctx.device, &waiti, std.math.maxInt(u64));
    _ = c.FT_Done_Face(face);
    _ = c.FT_Done_FreeType(ft);

    var pipeline_layout: vk.PipelineLayout = undefined;
    defer vk.destroyPipelineLayout(ctx.device, pipeline_layout, null);
    {
        const ci: vk.PipelineLayoutCreateInfo = .{
            .pushConstantRangeCount = shaders.shader.push_constant_ranges.len,
            .pPushConstantRanges = &shaders.shader.push_constant_ranges,
            .setLayoutCount = 1,
            .pSetLayouts = @ptrCast(&asset.descriptor_layout),
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
            //NOTE: idk
            .pRasterizationState = &.{ .lineWidth = 1.0, .polygonMode = .fill, .cullMode = .{ .back = false } },
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
            .pSetLayouts = @ptrCast(&asset.descriptor_layout),
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

    var scene_buffer: [max_frames]zkf.Buffer = undefined;
    defer for (scene_buffer) |buffer| {
        buffer.deinit(ctx.vka);
    };
    for (0..max_frames) |i| {
        const uBufferCI: vk.BufferCreateInfo = .{
            .size = @sizeOf(Scene),
            .usage = .{ .shader_device_address = true },
        };
        scene_buffer[i] = try .init(ctx.vka, uBufferCI, .mapped_vram);
    }
    var poses_buffer: [max_frames]zkf.Buffer = undefined;
    defer for (poses_buffer) |buffer| {
        buffer.deinit(ctx.vka);
    };
    for (&poses_buffer) |*buffer| {
        const ci: vk.BufferCreateInfo = .{
            .size = @sizeOf(Pose) * 5,
            .usage = .{ .shader_device_address = true },
        };
        buffer.* = try .init(ctx.vka, ci, .mapped_vram);
    }
    var mat_buf: [max_frames]zkf.Buffer = undefined;
    defer for (mat_buf) |buf| {
        buf.deinit(ctx.vka);
    };
    for (&mat_buf) |*buf| {
        const ci: vk.BufferCreateInfo = .{
            .size = @sizeOf(zkf.AssetManager.Material) * 5,
            .usage = .{ .shader_device_address = true },
        };
        buf.* = try .init(ctx.vka, ci, .mapped_vram);
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
    var scene: Scene = .{};
    var poses: [5]Pose = @splat(.{});
    var mats: [5]zkf.AssetManager.Material = undefined;
    var sel: u32 = 0;

    //some stats
    var frametime_acc: f32 = 0;
    const frametime_goal = 8333;
    var diff_acc: f32 = 0;

    arena_startup.deinit();
    while (!quit) {
        _ = arena_frame.reset(.retain_capacity);

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

        scene.projection = .perspective(cam.fov, aspect, 0.1, 32.0);
        scene.ortho = .ortho(0.0, @floatFromInt(rctx.windowsize.width), 0.0, @floatFromInt(rctx.windowsize.height));
        scene.cam = cam.pose;
        scene.selected = sel;
        for (0..3) |i| {
            const idx: f32 = @floatFromInt(i);
            const pos: Vec3 = .{ .x = (idx - 1.0) * 3.0, .y = -(idx), .z = 0.0 };
            const lookup: [4]Vec3 = .{
                Vec3{ .x = -1 },
                Vec3{ .x = 1 },
                Vec3{ .y = 1 },
                Vec3{ .y = -1 },
            };

            poses[i].pos = pos;
            poses[i].extra = 1.0;
            poses[i].rot = poses[i].rot.mul(.fromAngleAxis(std.math.pi * 0.5 * dT, lookup[i])).normalize();
            mats[i].albedo = handles[i].sampled;
        }
        poses[4] = helm.pose;
        poses_buffer[fif_index].write(0, poses);
        poses_buffer[fif_index].write(4 * @sizeOf(Pose), .{ .pos = .{ .z = -2 } });

        scene_buffer[fif_index].write(0, scene);
        mats[3].albedo = handle2.sampled;
        mats[4].albedo = helm_tex.sampled;
        mat_buf[fif_index].write(0, mats);

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
                .imageView = asset.getStorageImage(rctx.sc_img_views[swapchain_index]),
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
                vk.cmdBindDescriptorSets(cb, .graphics, pipeline_layout, 0, 1, @ptrCast(&asset.descriptor_set), 0, undefined);
                vk.cmdPushConstants(cb, pipeline_layout, .{ .vertex = true }, 0, @sizeOf(vk.DeviceAddress), std.mem.asBytes(&scene_buffer[fif_index].address(ctx.device)));
                vk.cmdPushConstants(cb, pipeline_layout, .{ .vertex = true }, 8, 8, @ptrCast(&poses_buffer[fif_index].address(ctx.device)));
                vk.cmdPushConstants(cb, pipeline_layout, .{ .vertex = true }, 16, 8, @ptrCast(&mat_buf[fif_index].address(ctx.device)));

                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&suzanne_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, suzanne_buffer.handle, vBufferSize, .uint32);
                vk.cmdDrawIndexed(cb, @intCast(suzanne.indices.items.len), 3, 0, 0, 0);

                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&plane_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, plane_buffer.handle, @sizeOf(f32) * plane_vertices.len, .uint16);
                vk.cmdDrawIndexed(cb, @intCast(quad_indices.len), 1, 0, 0, 3);

                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&asset.vertices.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, asset.indices.handle, 0, .uint16);
                vk.cmdDrawIndexed(cb, @intCast(helm.mesh.index_count), 1, 0, 0, 4);

                vk.cmdBindPipeline(cb, .graphics, skybox_pipeline);
                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&cube_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, cube_buffer.handle, @sizeOf(Vertex) * cube.vertices.items.len, .uint32);
                vk.cmdDrawIndexed(cb, @intCast(cube.indices.items.len), 1, 0, 0, 3);

                vk.cmdBindPipeline(cb, .graphics, text_pipeline);
                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&text_quad.handle), &.{0});
                const text = try std.fmt.allocPrint(a_frame, "frametimeg,: {d:.3}ms±😊", .{elasped / 1000});

                var pos: Vec2 = .{ .x = mouse_pos.x, .y = mouse_pos.y };
                const scale: f32 = 1;
                for (text, 0..) |char, i| {
                    if (char == ' ') {
                        pos.x += space_advance;
                        continue;
                    }
                    const ch = charmap.get(char) orelse continue;

                    const w: f32 = ch.scale.x * scale;
                    const h: f32 = ch.scale.y * scale;
                    const charmod: Vec2 = .{
                        .x = ch.bearing.x,
                        .y = ch.scale.y + ch.bearing.y,
                    };
                    const vertices = [_]f32{
                        charmod.x + pos.x,     charmod.y + pos.y - h, ch.uv.x,     ch.uv.y,
                        charmod.x + pos.x,     charmod.y + pos.y,     ch.uv.x,     ch.uv_max.y,
                        charmod.x + pos.x + w, charmod.y + pos.y,     ch.uv_max.x, ch.uv_max.y,
                        charmod.x + pos.x,     charmod.y + pos.y - h, ch.uv.x,     ch.uv.y,
                        charmod.x + pos.x + w, charmod.y + pos.y,     ch.uv_max.x, ch.uv_max.y,
                        charmod.x + pos.x + w, charmod.y + pos.y - h, ch.uv_max.x, ch.uv.y,
                    };
                    text_quad.write(quad_size * i, &vertices);
                    vk.cmdDraw(cb, 6, 1, @intCast(i * 6), 0);
                    pos.x += ch.advance * scale;
                }
            }

            vk.cmdBindPipeline(cb, .compute, boxblur_pipeline);
            vk.cmdBindDescriptorSets(cb, .compute, post_layout, 0, 1, @ptrCast(&asset.descriptor_set), 0, undefined);
            vk.cmdPushConstants(cb, post_layout, .{ .compute = true }, 0, 8, @ptrCast(&mouse_pos));
            vk.cmdPushConstants(cb, post_layout, .{ .compute = true }, 8, 4, @ptrCast(&rctx.sc_img_views[swapchain_index]));
            vk.cmdPushConstants(cb, post_layout, .{ .compute = true }, 12, 4, &.{ 0, 0, 0, 0 });
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
            try rctx.recreate_swap(&ctx, &asset);
        }
    }
    arena_frame.deinit();

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
