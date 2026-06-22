const std = @import("std");
const log = std.log.scoped(.howtovulkan);
const Io = std.Io;

const vk = @import("vk");
const shaders = @import("shaders");
const c = @import("c");

const zkf = @import("zkf.zig");
const sdl = @import("sdl.zig");
const math = @import("math.zig");

const gpu = @import("renderer/structs.zig");
const bufs = @import("renderer/buffers.zig");
const Swapchain = @import("renderer/Swapchain.zig");
const Renderer = @import("renderer/Renderer.zig");

const Vertex = math.Vertex;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;
const Vec2 = math.Vec2;
const Pose = zkf.Pose;
const Camera = zkf.Camera;

///build
const vk_extensions = @import("vk_extensions");

pub fn getShaderModule(device: vk.Device, shader: anytype) !vk.ShaderModule {
    var module: vk.ShaderModule = undefined;
    const ci: vk.ShaderModuleCreateInfo = .{
        .codeSize = shader.spirv.len,
        .pCode = @ptrCast(&shader.spirv),
    };
    try vk.createShaderModule(device, &ci, null, &module);
    return module;
}

const Glyph = struct {
    uv: Vec2 = .{},
    uv_max: Vec2 = .{},
    bearing: Vec2 = .{},
    scale: Vec2 = .{},
    advance: f32 = 0,
};
var charmap: std.AutoHashMapUnmanaged(u21, Glyph) = .empty;
var space_advance: f32 = undefined;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    var io = init.io;
    const a_static = init.arena.allocator();
    var arena_startup = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // const a_startup = arena_startup.allocator();
    // var arena_frame = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // const a_frame = arena_frame.allocator();

    var cam: Camera = .{ .pose = .{ .pos = .{ .z = 6.0 }, .extra = 0 } };

    var renderer: Renderer = try .init(gpa);
    defer renderer.deinit(gpa);

    var sampler: vk.Sampler = undefined;
    const sampler_ci: vk.SamplerCreateInfo = .{
        .magFilter = .linear,
        .minFilter = .linear,
        .mipmapMode = .linear,
        .anisotropyEnable = .True,
        .maxAnisotropy = 8.0,
        .borderColor = .float_transparent_black,
        .maxLod = 12,
    };
    try vk.createSampler(renderer.ctx.device, &sampler_ci, null, &sampler);
    defer vk.destroySampler(renderer.ctx.device, sampler, null);

    loop: while (true) {
        break :loop;
    }

    const sampler_write: vk.WriteDescriptorSet = .{
        .dstSet = renderer.desc_man.set,
        .dstBinding = 2,
        .descriptorType = .sampler,
        .descriptorCount = 1,
        .dstArrayElement = 0,
        .pImageInfo = &.{.{
            .sampler = sampler,
        }},
    };
    vk.updateDescriptorSets(renderer.ctx.device, 1, @ptrCast(&sampler_write), 0, undefined);

    var window_extent: vk.Extent2D = .{ .width = 1920, .height = 1080 };
    const window = try sdl.createWindow("hello", @intCast(window_extent.width), @intCast(window_extent.height), .{
        .vulkan = true,
        .resizable = true,
        .fullscreen = true,
        .borderless = true,
    });

    //window? window owns input
    var mouse_mode = true;
    var mouse_pos: Vec2 = .{ .x = 0, .y = 0 };
    var mouse_state: sdl.MouseButtonFlags = .{};
    _ = sdl.setWindowRelativeMouseMode(window, true);
    var fullscreen = true;

    const surface = try sdl.vulkan.createSurface(window, renderer.ctx.instance, null);
    var swapchain: Swapchain = try .init(&renderer.ctx, gpa, surface, window_extent);
    defer swapchain.deinit(&renderer.ctx, gpa);

    var offscreen_render = try renderer.createTexture2D(
        .r16g16b16a16_unorm,
        window_extent,
        .{ .transfer_src = true, .color_attachment = true },
        .{ .color = true },
    );
    defer renderer.destroyTexture(offscreen_render);

    var triangle_id = try renderer.createTexture2D(
        .r32_uint,
        window_extent,
        .{ .color_attachment = true },
        .{ .color = true },
    );
    defer renderer.destroyTexture(triangle_id);

    var depth_buffer = try renderer.createTexture2D(
        .d32_sfloat,
        window_extent,
        .{ .depth_stencil_attachment = true },
        .{ .depth = true },
    );
    defer renderer.destroyTexture(depth_buffer);

    // const suzanne_pulled = try renderer.loadObj(a_static, &io, "assets/suzanne.obj");
    const cube = try renderer.loadObj(a_static, &io, "assets/cube.obj");
    // const plane = asset.addMesh(&quad_indices, @ptrCast(&plane_vertices));

    const helm = try renderer.loadGltf(io, gpa, "zig-out/assets/DamagedHelmet/DamagedHelmet.gltf");
    defer renderer.unloadModel(gpa, &helm);

    const sponza = try renderer.loadGltf(io, gpa, "zig-out/assets/Sponza/Sponza.gltf");
    defer renderer.unloadModel(gpa, &sponza);

    //FIX: text
    // const quad_size = @sizeOf(f32) * 6 * 4;
    // const text_quad = try bufs.Buffer.init(ctx.vka, .{
    //     .size = quad_size * 100,
    //     .usage = .{ .vertex_buffer = true },
    // }, .mapped_vram);
    // defer text_quad.deinit(ctx.vka);

    //textures

    //FIX: suzanne
    // var handles: [3]Renderer.Hate = undefined;
    // defer for (handles) |handle| {
    //     renderer.popHate(&ctx, handle);
    // };
    // for (0..3) |i| {
    //     var buf: [128]u8 = @splat(0);
    //     const filename = try std.fmt.bufPrintSentinel(&buf, "assets/suzanne{}.ktx2", .{i}, 0);
    //     handles[i] = try renderer.loadTextureFromFile(&ctx, gpa, commandPool, filename);
    // }

    const skybox = try renderer.loadTextureFromFile(gpa, "assets/skybox.ktx2");
    defer renderer.destroyTexture(skybox);
    const skybox_id = renderer.desc_man.appendSampled(renderer.ctx.device, skybox.view, .read_only_optimal);

    //FIX:
    // //fonts
    // var ft: c.FT_Library = undefined;
    // if (c.FT_Init_FreeType(&ft) != 0) {
    //     log.info("Failed to init freetype.", .{});
    //     return error.Freetype;
    // }
    // var face: c.FT_Face = undefined;
    // const font = "/usr/share/fonts/ibm-plex-sans-fonts/IBMPlexSans-Regular.otf";
    // if (c.FT_New_Face(ft, font, 0, &face) != 0) {
    //     log.info("Failed to init face", .{});
    //     return error.Face;
    // }
    // const font_size = 32;
    // if (c.FT_Set_Pixel_Sizes(face, 0, font_size) != 0) @panic("");

    // const atlas_size = 1024.0;
    // var atlas_offsetx: u32 = 0;
    // var atlas_offsety: u32 = 0;
    // const atlas_ci: vk.ImageCreateInfo = .{
    //     .imageType = .@"2d",
    //     .format = .r8_unorm,
    //     .extent = .{ .width = atlas_size, .height = atlas_size, .depth = 1 },
    //     .samples = .{ .@"1" = true },
    //     .usage = .{ .transfer_dst = true, .sampled = true },
    //     .mipLevels = 1,
    //     .arrayLayers = 1,
    // };
    // const font_atlas = try renderer.allocImage(&ctx, atlas_ci);
    // defer renderer.freeImage(&ctx, font_atlas);
    // try vk.nameHandle(ctx.device, renderer.getImage(font_atlas), "Font Atlas");

    // const atlas_view_ci: vk.ImageViewCreateInfo = .{
    //     .format = .r8_unorm,
    //     .image = renderer.getImage(font_atlas),
    //     .viewType = .@"2d",
    //     .subresourceRange = .{
    //         .aspectMask = .{ .color = true },
    //         .layerCount = 1,
    //         .levelCount = 1,
    //     },
    // };
    // const atlas_view = try renderer.allocSampledImage(&ctx, atlas_view_ci);
    // defer renderer.freeSampledImage(&ctx, atlas_view);

    // const semaphore_type: vk.SemaphoreTypeCreateInfo = .{ .semaphoreType = .timeline };
    // const semaphore_ci: vk.SemaphoreCreateInfo = .{ .pNext = &semaphore_type };
    // var upload_semaphore: vk.Semaphore = undefined;
    // try vk.createSemaphore(ctx.device, &semaphore_ci, null, &upload_semaphore);
    // defer vk.destroySemaphore(ctx.device, upload_semaphore, null);
    // var upload_count: u64 = 0;

    // const glyph_size = font_size * font_size;
    // const transfer_buffer_size = 5;
    // const transfer_ci: vk.BufferCreateInfo = .{ .size = glyph_size * transfer_buffer_size, .usage = .{ .transfer_src = true } };
    // const transfer_buffer: bufs.Buffer = try .init(ctx.vka, transfer_ci, .mapped_vram);
    // defer transfer_buffer.deinit(ctx.vka);

    // var cmd_buf: vk.CommandBuffer = undefined;
    // const cmd_buf_ai: vk.CommandBufferAllocateInfo = .{ .commandPool = commandPool, .commandBufferCount = 1, .level = .primary };
    // try vk.allocateCommandBuffers(ctx.device, &cmd_buf_ai, @ptrCast(&cmd_buf));
    // defer vk.freeCommandBuffers(ctx.device, commandPool, 1, @ptrCast(&cmd_buf));
    // const cmd_binfo: vk.CommandBufferBeginInfo = .{ .flags = .{ .one_time_submit = true } };

    // var transfer_offset: u32 = 0;

    // {
    //     try vk.beginCommandBuffer(cmd_buf, &cmd_binfo);
    //     var layout_barrier: vk.ImageMemoryBarrier2 = .{
    //         .dstStageMask = .{ .all_transfer = true },
    //         .dstAccessMask = .{ .transfer_write = true },
    //         .oldLayout = .undefined,
    //         .newLayout = .transfer_dst_optimal,
    //         .image = renderer.getImage(font_atlas),
    //         .subresourceRange = .{
    //             .aspectMask = .{ .color = true },
    //             .levelCount = 1,
    //             .layerCount = 1,
    //         },
    //     };
    //     var barrier_texinfo: vk.DependencyInfo = .{
    //         .imageMemoryBarrierCount = 1,
    //         .pImageMemoryBarriers = @ptrCast(&layout_barrier),
    //     };
    //     vk.cmdPipelineBarrier2(cmd_buf, &barrier_texinfo);
    // }

    // for (31..128) |i| {
    //     if (c.FT_Load_Char(face, i, c.FT_LOAD_RENDER) != 0) {
    //         log.info("failed to load {c}", .{@as(u8, @intCast(i))});
    //         continue;
    //     }
    //     const glyph = face.*.glyph.*;
    //     if (i == ' ') {
    //         space_advance = @floatFromInt(glyph.advance.x >> 6);
    //         continue;
    //     }

    //     // log.debug("{c}: {}", .{ @as(u8, @intCast(i)), glyph.metrics });
    //     // log.debug("{s}", .{std.meta.fieldNames(@TypeOf(glyph.metrics))});

    //     var out: Glyph = .{
    //         .bearing = .{ .x = @floatFromInt(glyph.bitmap_left), .y = @floatFromInt(-glyph.bitmap_top) },
    //         .advance = @floatFromInt(glyph.advance.x >> 6),
    //     };

    //     transfer_buffer.write(transfer_offset * glyph_size, glyph.bitmap.buffer[0 .. glyph.bitmap.rows * glyph.bitmap.width]);

    //     {
    //         if (atlas_offsetx + glyph.bitmap.width >= atlas_size) {
    //             atlas_offsety += font_size;
    //             atlas_offsetx = 0;
    //         }
    //         const copy_test: vk.BufferImageCopy = .{
    //             .imageSubresource = .{
    //                 .aspectMask = .{ .color = true },
    //                 .layerCount = 1,
    //             },
    //             .imageExtent = .{
    //                 .depth = 1,
    //                 .width = glyph.bitmap.width,
    //                 .height = glyph.bitmap.rows,
    //             },
    //             .imageOffset = .{
    //                 .x = @intCast(atlas_offsetx),
    //                 .y = @intCast(atlas_offsety),
    //             },
    //             .bufferOffset = transfer_offset * glyph_size,
    //         };
    //         vk.cmdCopyBufferToImage(cmd_buf, transfer_buffer.handle, renderer.getImage(font_atlas), .transfer_dst_optimal, 1, &.{copy_test});
    //         transfer_offset += 1;

    //         out.uv = .{
    //             .x = @as(f32, @floatFromInt(atlas_offsetx)) / atlas_size,
    //             .y = @as(f32, @floatFromInt(atlas_offsety)) / atlas_size,
    //         };
    //         out.uv_max = .{
    //             .x = @as(f32, @floatFromInt(atlas_offsetx + glyph.bitmap.width)) / atlas_size,
    //             .y = @as(f32, @floatFromInt(atlas_offsety + glyph.bitmap.rows)) / atlas_size,
    //         };
    //         const yscale = @as(f32, @floatFromInt(glyph.bitmap.rows));
    //         atlas_offsetx += glyph.bitmap.width + 2;
    //         const ratio = (out.uv_max.x - out.uv.x) / (out.uv_max.y - out.uv.y);
    //         out.scale = .{ .x = ratio * yscale, .y = yscale };
    //         try charmap.put(a_static, @intCast(i), out);

    //         if (transfer_offset == 5) {
    //             try vk.endCommandBuffer(cmd_buf);
    //             const smp_submit: vk.SemaphoreSubmitInfo = .{
    //                 .semaphore = upload_semaphore,
    //                 .stageMask = .{ .all_transfer = true },
    //                 .value = upload_count + 1,
    //             };
    //             const submiti: vk.SubmitInfo2 = .{
    //                 .commandBufferInfoCount = 1,
    //                 .pCommandBufferInfos = &.{.{ .commandBuffer = cmd_buf }},
    //                 .signalSemaphoreInfoCount = 1,
    //                 .pSignalSemaphoreInfos = &.{smp_submit},
    //             };
    //             try vk.queueSubmit2(ctx.queue, 1, &.{submiti}, null);
    //             const waiti: vk.SemaphoreWaitInfo = .{
    //                 .semaphoreCount = 1,
    //                 .pSemaphores = @ptrCast(&upload_semaphore),
    //                 .pValues = &.{upload_count + 1},
    //             };
    //             try vk.waitSemaphores(ctx.device, &waiti, std.math.maxInt(u64));
    //             upload_count += 1;

    //             try vk.beginCommandBuffer(cmd_buf, &cmd_binfo);

    //             transfer_offset = 0;
    //         }
    //     }
    // }
    // var layout_barrier: vk.ImageMemoryBarrier2 = .{
    //     .srcStageMask = .{ .all_transfer = true },
    //     .srcAccessMask = .{ .transfer_write = true },
    //     .oldLayout = .transfer_dst_optimal,
    //     .newLayout = .read_only_optimal,
    //     .image = renderer.getImage(font_atlas),
    //     .subresourceRange = .{
    //         .aspectMask = .{ .color = true },
    //         .levelCount = 1,
    //         .layerCount = 1,
    //     },
    // };
    // var barrier_texinfo: vk.DependencyInfo = .{
    //     .imageMemoryBarrierCount = 1,
    //     .pImageMemoryBarriers = @ptrCast(&layout_barrier),
    // };
    // vk.cmdPipelineBarrier2(cmd_buf, &barrier_texinfo);
    // try vk.endCommandBuffer(cmd_buf);
    // const smp_submit: vk.SemaphoreSubmitInfo = .{
    //     .semaphore = upload_semaphore,
    //     .value = upload_count + 1,
    // };
    // const submiti: vk.SubmitInfo2 = .{
    //     .commandBufferInfoCount = 1,
    //     .pCommandBufferInfos = &.{.{ .commandBuffer = cmd_buf }},
    //     .signalSemaphoreInfoCount = 1,
    //     .pSignalSemaphoreInfos = &.{smp_submit},
    // };
    // try vk.queueSubmit2(ctx.queue, 1, &.{submiti}, null);
    // const waiti: vk.SemaphoreWaitInfo = .{
    //     .semaphoreCount = 1,
    //     .pSemaphores = @ptrCast(&upload_semaphore),
    //     .pValues = &.{upload_count + 1},
    // };
    // try vk.waitSemaphores(ctx.device, &waiti, std.math.maxInt(u64));
    // _ = c.FT_Done_Face(face);
    // _ = c.FT_Done_FreeType(ft);

    var skybox_pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(renderer.ctx.device, skybox_pipeline, null);
    {
        const skybox_module = try getShaderModule(renderer.ctx.device, shaders.skybox);
        defer vk.destroyShaderModule(renderer.ctx.device, skybox_module, null);
        const stages: [2]vk.PipelineShaderStageCreateInfo = .{
            .{ .module = skybox_module, .pName = "main", .stage = .{ .vertex = true } },
            .{ .module = skybox_module, .pName = "main", .stage = .{ .fragment = true } },
        };
        const render_ci: vk.PipelineRenderingCreateInfo = .{
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = &.{.r16g16b16a16_unorm},
            .depthAttachmentFormat = .d32_sfloat,
        };
        const blend_attachment: vk.PipelineColorBlendAttachmentState = .{ .colorWriteMask = @bitCast(@as(u32, 0xF)) };
        var ci: vk.GraphicsPipelineCreateInfo = .{
            .pNext = &render_ci,
            .stageCount = stages.len,
            .pStages = &stages,
            .pVertexInputState = &.{},
            .pInputAssemblyState = &.{ .topology = .triangle_list },
            .pViewportState = &.{ .viewportCount = 1, .scissorCount = 1 },
            .pRasterizationState = &.{ .lineWidth = 1.0, .polygonMode = .fill, .cullMode = .{ .front = true } },
            .pMultisampleState = &.{ .rasterizationSamples = .{ .@"1" = true } },
            .pDepthStencilState = &.{ .depthTestEnable = .True, .depthWriteEnable = .True, .depthCompareOp = .equal },
            .pColorBlendState = &.{ .attachmentCount = 1, .pAttachments = @ptrCast(&blend_attachment) },
            .pDynamicState = &.{ .dynamicStateCount = 2, .pDynamicStates = &.{ .viewport, .scissor } },
            .layout = renderer.graphics_layout,
        };
        try vk.createGraphicsPipelines(renderer.ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&skybox_pipeline));
    }

    var text_pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(renderer.ctx.device, text_pipeline, null);
    {
        const text_module = try getShaderModule(renderer.ctx.device, shaders.text);
        defer vk.destroyShaderModule(renderer.ctx.device, text_module, null);
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
            .pColorAttachmentFormats = &.{.r16g16b16a16_unorm},
            .depthAttachmentFormat = .d32_sfloat,
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
            .layout = renderer.graphics_layout,
        };
        try vk.createGraphicsPipelines(renderer.ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&text_pipeline));
    }

    //TODO: color attachmnt + pipeline creating + starting barriers all should be created from the same function call
    var pbr_pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(renderer.ctx.device, pbr_pipeline, null);
    {
        const pbr_module = try getShaderModule(renderer.ctx.device, shaders.pbr);
        defer vk.destroyShaderModule(renderer.ctx.device, pbr_module, null);
        const stages: [2]vk.PipelineShaderStageCreateInfo = .{
            .{ .module = pbr_module, .pName = "main", .stage = .{ .vertex = true } },
            .{ .module = pbr_module, .pName = "main", .stage = .{ .fragment = true } },
        };
        const render_ci: vk.PipelineRenderingCreateInfo = .{
            .colorAttachmentCount = 2,
            .pColorAttachmentFormats = &.{ .r16g16b16a16_unorm, .r32_uint },
            .depthAttachmentFormat = .d32_sfloat,
        };
        const blend_attachments = [_]vk.PipelineColorBlendAttachmentState{
            .{ .colorWriteMask = @bitCast(@as(u32, 0xF)) },
            .{ .colorWriteMask = @bitCast(@as(u32, 0xF)) },
        };
        const ci: vk.GraphicsPipelineCreateInfo = .{
            .pNext = &render_ci,
            .stageCount = stages.len,
            .pStages = &stages,
            .pVertexInputState = &.{},
            .pInputAssemblyState = &.{ .topology = .triangle_list },
            .pViewportState = &.{ .viewportCount = 1, .scissorCount = 1 },
            .pRasterizationState = &.{ .lineWidth = 1.0, .polygonMode = .fill, .cullMode = .{ .back = true } },
            .pMultisampleState = &.{ .rasterizationSamples = .{ .@"1" = true } },
            .pDepthStencilState = &.{ .depthTestEnable = .True, .depthCompareOp = .less_or_equal, .depthWriteEnable = .True },
            .pColorBlendState = &.{ .attachmentCount = @intCast(blend_attachments.len), .pAttachments = &blend_attachments },
            .pDynamicState = &.{ .dynamicStateCount = 2, .pDynamicStates = &.{ .viewport, .scissor } },
            .layout = renderer.graphics_layout,
        };

        try vk.createGraphicsPipelines(renderer.ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&pbr_pipeline));
    }

    var post_layout: vk.PipelineLayout = undefined;
    defer vk.destroyPipelineLayout(renderer.ctx.device, post_layout, null);
    {
        const ci: vk.PipelineLayoutCreateInfo = .{
            .setLayoutCount = 1,
            .pSetLayouts = @ptrCast(&renderer.desc_man.layout),
            .pushConstantRangeCount = shaders.box.push_constant_ranges.len,
            .pPushConstantRanges = @ptrCast(&shaders.box.push_constant_ranges),
        };
        try vk.createPipelineLayout(renderer.ctx.device, &ci, null, &post_layout);
    }

    var boxblur_pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(renderer.ctx.device, boxblur_pipeline, null);
    {
        const box_module = try getShaderModule(renderer.ctx.device, shaders.box);
        defer vk.destroyShaderModule(renderer.ctx.device, box_module, null);
        const ci: vk.ComputePipelineCreateInfo = .{
            .layout = post_layout,
            .stage = .{ .stage = .{ .compute = true }, .module = box_module, .pName = "main" },
        };
        try vk.createComputePipelines(renderer.ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&boxblur_pipeline));
    }

    //basic dt and quit
    var last_time = Io.Clock.now(.real, io).toMicroseconds();
    var quit: bool = false;

    var sel: u32 = 0;

    //some stats
    var frametime_acc: f32 = 0;
    const frametime_goal = 8333;
    var diff_acc: f32 = 0;

    arena_startup.deinit();
    while (!quit) {
        //TODO: dont just retain_capacity
        // _ = arena_frame.reset(.retain_capacity);

        const wait_info: vk.SemaphoreWaitInfo = .{
            .semaphoreCount = 1,
            .pSemaphores = @ptrCast(&renderer.loop.handle),
            .pValues = &.{renderer.fif_values[renderer.fif_index]},
        };
        try vk.waitSemaphores(renderer.ctx.device, &wait_info, std.math.maxInt(u64));
        renderer.loop.val += 1;
        const current_image = try swapchain.acquire(&renderer.ctx, renderer.fif_semaphores[renderer.fif_index]);

        //reduces input latency or smth
        // try Io.sleep(io, .fromMicroseconds(4000), .real);

        const elasped: f32 = @floatFromInt(Io.Clock.now(.real, io).toMicroseconds() - last_time);
        last_time = Io.Clock.now(.real, io).toMicroseconds();
        const flast: f64 = @as(f64, @floatFromInt(last_time)) / 1_000_000;
        const dT = elasped / 1_000_000.0;

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
                    .window_resized => swapchain.should_recreate = true,
                    .key_down => {
                        if (!event.key.repeat) {
                            switch (event.key.scancode) {
                                .h => sel = (sel + 1) % 3,
                                .escape => quit = true,
                                .f11 => {
                                    fullscreen = !fullscreen;
                                    _ = sdl.setWindowFullscreen(window, fullscreen);
                                },
                                .f10 => {
                                    mouse_mode = !mouse_mode;
                                    _ = sdl.setWindowRelativeMouseMode(window, mouse_mode);
                                },
                                else => {},
                            }
                        }
                    },
                    else => {},
                }
            }
        }

        const aspect = @as(f32, @floatFromInt(window_extent.width)) / @as(f32, @floatFromInt(window_extent.height));

        //FIX: do this properly
        if (renderer.scene.offset == 2) {
            renderer.scene.reset();
            renderer.poses.reset();
        }

        renderer.scene.append(.{
            .projection = .perspective(cam.fov, aspect, 0.1, 32.0),
            .ortho = .ortho(0.0, @floatFromInt(window_extent.width), 0.0, @floatFromInt(window_extent.height)),
            .cam = cam.pose,
            .selected = sel,
            .light_pos = .{
                .x = @as(f32, @floatCast(@sin(std.math.pi * flast * 0.25))) * 4.0,
                .y = @as(f32, @floatCast(@sin(std.math.pi * flast * 0.125))) * 4.0 - 4,
            },
        });

        // for (0..3) |i| {
        //     const idx: f32 = @floatFromInt(i);
        //     const pos: Vec3 = .{ .x = (idx - 1.0) * 3.0, .y = -(idx), .z = 0.0 };
        //     const lookup: [4]Vec3 = .{
        //         Vec3{ .x = -1 },
        //         Vec3{ .x = 1 },
        //         Vec3{ .y = 1 },
        //         Vec3{ .y = -1 },
        //     };

        //     poses[i].pos = pos;
        //     poses[i].extra = 1.0;
        //     poses[i].rot = poses[i].rot.mul(.fromAngleAxis(std.math.pi * 0.5 * dT, lookup[i])).normalize();
        //     mats[i].albedo = handles[i].sampled;
        // }
        renderer.poses.appendSlice(&@as([25]Pose, @splat(.{})));
        // poses[4] = .{ .pos = .{ .x = 0, .y = -4, .z = 0 } };
        // poses_buffer[fif_index].write(0, poses);
        // poses_buffer[fif_index].write(4 * @sizeOf(Pose), .{ .pos = .{ .z = -2 } });

        const cb: vk.CommandBuffer = renderer.cmdbuf[renderer.fif_index];
        try vk.resetCommandBuffer(cb, .{});

        {
            try vk.beginCommandBuffer(cb, &.{ .flags = .{ .one_time_submit = true } });

            // generate both barriers and rendering attachment info with some renderer call?
            const output_barriers = [_]vk.ImageMemoryBarrier2{
                .{
                    .srcStageMask = .{ .compute_shader = true, .color_attachment_output = true },
                    .srcAccessMask = .{},
                    .dstStageMask = .{ .color_attachment_output = true },
                    .dstAccessMask = .{ .color_attachment_write = true },
                    .oldLayout = .undefined,
                    .newLayout = .attachment_optimal,
                    .image = offscreen_render.handle,
                    .subresourceRange = .{ .aspectMask = .{ .color = true }, .levelCount = 1, .layerCount = 1 },
                },
                .{
                    .srcStageMask = .{ .color_attachment_output = true },
                    .srcAccessMask = .{},
                    .dstStageMask = .{ .color_attachment_output = true },
                    .dstAccessMask = .{ .color_attachment_write = true },
                    .oldLayout = .undefined,
                    .newLayout = .attachment_optimal,
                    .image = triangle_id.handle,
                    .subresourceRange = .{ .aspectMask = .{ .color = true }, .levelCount = 1, .layerCount = 1 },
                },
                .{
                    .srcStageMask = .{ .blit = true },
                    .srcAccessMask = .{},
                    .dstStageMask = .{ .blit = true },
                    .dstAccessMask = .{ .transfer_write = true },
                    .oldLayout = .undefined,
                    .newLayout = .general,
                    .image = current_image,
                    .subresourceRange = .{ .aspectMask = .{ .color = true }, .levelCount = 1, .layerCount = 1 },
                },
                .{
                    .srcStageMask = .{ .late_fragment_tests = true },
                    .srcAccessMask = .{ .depth_stencil_attachment_write = true },
                    .dstStageMask = .{ .early_fragment_tests = true },
                    .dstAccessMask = .{ .depth_stencil_attachment_write = true },
                    .oldLayout = .undefined,
                    .newLayout = .attachment_optimal,
                    .image = depth_buffer.handle,
                    .subresourceRange = .{ .aspectMask = .{ .depth = true }, .levelCount = 1, .layerCount = 1 },
                },
            };
            vk.cmdPipelineBarrier2(cb, &.{ .imageMemoryBarrierCount = @intCast(output_barriers.len), .pImageMemoryBarriers = &output_barriers });

            const color_attach_infos = [_]vk.RenderingAttachmentInfo{
                .{
                    .imageView = offscreen_render.view,
                    .imageLayout = .attachment_optimal,
                    .loadOp = .clear,
                    .storeOp = .store,
                    .clearValue = .{ .color = .{ .float32 = .{ 0.0, 0.0, 0.0, 1.0 } } },
                },
                .{
                    .imageView = triangle_id.view,
                    .imageLayout = .attachment_optimal,
                    .loadOp = .clear,
                    .storeOp = .store,
                    .clearValue = .{ .color = .{ .uint32 = @splat(0.0) } },
                },
            };
            const depth_attach_info: vk.RenderingAttachmentInfo = .{
                .imageView = depth_buffer.view,
                .imageLayout = .attachment_optimal,
                .loadOp = .clear,
                .storeOp = .dont_care,
                .clearValue = .{ .depthStencil = .{ .depth = 1.0, .stencil = 0 } },
            };

            const rendering_info: vk.RenderingInfo = .{
                .renderArea = .{ .extent = window_extent },
                .layerCount = 1,
                .colorAttachmentCount = @intCast(color_attach_infos.len),
                .pColorAttachments = &color_attach_infos,
                .pDepthAttachment = &depth_attach_info,
            };

            {
                vk.cmdBeginRendering(cb, &rendering_info);
                defer vk.cmdEndRendering(cb);
                const vp: vk.Viewport = .{
                    .width = @floatFromInt(window_extent.width),
                    .height = @floatFromInt(window_extent.height),
                    .maxDepth = 1.0,
                    .minDepth = 0.0,
                };
                vk.cmdSetViewport(cb, 0, 1, @ptrCast(&vp));
                const scissor: vk.Rect2D = .{ .extent = window_extent };
                vk.cmdSetScissor(cb, 0, 1, @ptrCast(&scissor));

                vk.cmdBindPipeline(cb, .graphics, pbr_pipeline);
                vk.cmdBindIndexBuffer(cb, renderer.indices.handle(), 0, .uint32);
                vk.cmdBindDescriptorSets(cb, .graphics, renderer.graphics_layout, 0, 1, @ptrCast(&renderer.desc_man.set), 0, undefined);
                const push: gpu.Push = .{
                    .vertices = renderer.vertices.bda(renderer.ctx.device),
                    .scene = renderer.scene.bda(renderer.ctx.device),
                    .poses = renderer.poses.bda(renderer.ctx.device),
                    .materials = renderer.materials.bda(renderer.ctx.device),
                    .fif_index = renderer.fif_index,
                };
                vk.cmdPushConstants(cb, renderer.graphics_layout, .{ .vertex = true }, 0, @sizeOf(gpu.Push), @ptrCast(&push));

                vk.cmdBeginDebugUtilsLabelEXT(cb, &.{ .pLabelName = "Vertex Pulling" });

                //FIX:
                // vk.cmdDrawIndexed(cb, plane.index_count, 1, plane.start_index, plane.start_vertex, 4);
                // vk.cmdDrawIndexed(cb, suzanne_pulled.index_count, 3, suzanne_pulled.start_index, suzanne_pulled.start_vertex, 0);
                vk.cmdDrawIndexed(cb, helm.meshes[0].offsets.index_count, 1, helm.meshes[0].offsets.start_index, helm.meshes[0].offsets.start_vertex, helm.meshes[0].material);

                //TODO: multiple meshes part of 1 model, how to resolve position then?
                for (sponza.meshes) |mesh| {
                    vk.cmdDrawIndexed(cb, mesh.offsets.index_count, 1, mesh.offsets.start_index, mesh.offsets.start_vertex, mesh.material);
                }

                vk.cmdEndDebugUtilsLabelEXT(cb);

                // vk.cmdBeginDebugUtilsLabelEXT(cb, &.{ .pLabelName = "Skybox" });

                // vk.cmdBindPipeline(cb, .graphics, skybox_pipeline);
                // vk.cmdDrawIndexed(cb, cube.offsets.index_count, 1, cube.offsets.start_index, cube.offsets.start_vertex, skybox_id);

                // vk.cmdEndDebugUtilsLabelEXT(cb);

                _ = cube;
                _ = skybox_id;
                vk.cmdBeginDebugUtilsLabelEXT(cb, &.{ .pLabelName = "Text" });

                //FIX:
                // vk.cmdBindPipeline(cb, .graphics, text_pipeline);
                // vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&text_quad.handle), &.{0});

                // //cant know
                // var pos: Vec2 = .{ .x = mouse_pos.x, .y = mouse_pos.y };
                // //TODO: new lines
                // const text = try std.fmt.allocPrint(a_frame, "frametimeg,: {d:.3}ms±😊\n {}, {}", .{ elasped / 1000, window_extent.width, window_extent.height });
                // const scale: f32 = 1;
                // for (text, 0..) |char, i| {
                //     if (char == ' ') {
                //         pos.x += space_advance;
                //         continue;
                //     }
                //     const ch = charmap.get(char) orelse continue;

                //     const w: f32 = ch.scale.x * scale;
                //     const h: f32 = ch.scale.y * scale;
                //     const charmod: Vec2 = .{
                //         .x = ch.bearing.x * scale,
                //         .y = (ch.scale.y + ch.bearing.y) * scale,
                //     };
                //     // log.debug("{c}: {}", .{ char, charmod });
                //     const vertices = [_]f32{
                //         charmod.x + pos.x,     charmod.y + pos.y - h, ch.uv.x,     ch.uv.y,
                //         charmod.x + pos.x,     charmod.y + pos.y,     ch.uv.x,     ch.uv_max.y,
                //         charmod.x + pos.x + w, charmod.y + pos.y,     ch.uv_max.x, ch.uv_max.y,
                //         charmod.x + pos.x,     charmod.y + pos.y - h, ch.uv.x,     ch.uv.y,
                //         charmod.x + pos.x + w, charmod.y + pos.y,     ch.uv_max.x, ch.uv_max.y,
                //         charmod.x + pos.x + w, charmod.y + pos.y - h, ch.uv_max.x, ch.uv.y,
                //     };
                //     text_quad.write(quad_size * i, &vertices);
                //     vk.cmdDraw(cb, 6, 1, @intCast(i * 6), 0);
                //     pos.x += ch.advance * scale;
                // }
                // vk.cmdEndDebugUtilsLabelEXT(cb);
            }

            // vk.cmdBeginDebugUtilsLabelEXT(cb, &.{ .pLabelName = "Post Proccess" });
            vk.cmdBindPipeline(cb, .compute, boxblur_pipeline);
            // vk.cmdBindDescriptorSets(cb, .compute, post_layout, 0, 1, @ptrCast(&renderer.descriptor_set), 0, undefined);
            // vk.cmdPushConstants(cb, post_layout, .{ .compute = true }, 0, 8, @ptrCast(&mouse_pos));
            // vk.cmdPushConstants(cb, post_layout, .{ .compute = true }, 8, 4, @ptrCast(&offscreen_view));
            const compute_barrier1: vk.ImageMemoryBarrier2 = .{
                .srcStageMask = .{ .color_attachment_output = true },
                .srcAccessMask = .{ .color_attachment_write = true },
                .dstStageMask = .{ .compute_shader = true },
                .dstAccessMask = .{ .shader_storage_read = true, .shader_storage_write = true },
                .oldLayout = .attachment_optimal,
                .newLayout = .general,
                .image = offscreen_render.handle,
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
            };
            vk.cmdPipelineBarrier2(cb, &.{ .imageMemoryBarrierCount = 1, .pImageMemoryBarriers = @ptrCast(&compute_barrier1) });
            vk.cmdDispatch(cb, (window_extent.width / shaders.box.local_size[0]) + 1, (window_extent.height / shaders.box.local_size[1]) + 1, 1);

            // vk.cmdEndDebugUtilsLabelEXT(cb);

            vk.cmdBeginDebugUtilsLabelEXT(cb, &.{ .pLabelName = "Blit" });
            const transfer_barrier: vk.ImageMemoryBarrier2 = .{
                .srcStageMask = .{ .compute_shader = true },
                .srcAccessMask = .{ .shader_storage_write = true },
                .dstStageMask = .{ .blit = true },
                .dstAccessMask = .{ .transfer_read = true },
                .oldLayout = .general,
                .newLayout = .transfer_src_optimal,
                .image = offscreen_render.handle,
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
            };
            vk.cmdPipelineBarrier2(cb, &.{ .imageMemoryBarrierCount = 1, .pImageMemoryBarriers = @ptrCast(&transfer_barrier) });

            const blit_regions: vk.ImageBlit = .{
                .srcSubresource = .{
                    .aspectMask = .{ .color = true },
                    .layerCount = 1,
                },
                .srcOffsets = .{
                    .{},
                    .{ .x = @intCast(window_extent.width), .y = @intCast(window_extent.height), .z = 1 },
                },
                .dstSubresource = .{
                    .aspectMask = .{ .color = true },
                    .layerCount = 1,
                },
                .dstOffsets = .{
                    .{},
                    .{ .x = @intCast(window_extent.width), .y = @intCast(window_extent.height), .z = 1 },
                },
            };

            vk.cmdBlitImage(cb, offscreen_render.handle, .transfer_src_optimal, current_image, .general, 1, &.{blit_regions}, .linear);
            vk.cmdEndDebugUtilsLabelEXT(cb);

            const present_barrier: vk.ImageMemoryBarrier2 = .{
                .srcStageMask = .{ .blit = true },
                .srcAccessMask = .{ .transfer_write = true },
                .dstStageMask = .{ .blit = true },
                .dstAccessMask = .{},
                .oldLayout = .general,
                .newLayout = .present_srcKHR,
                .image = current_image,
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
            };

            vk.cmdPipelineBarrier2(cb, &.{
                .imageMemoryBarrierCount = 1,
                .pImageMemoryBarriers = @ptrCast(&present_barrier),
            });

            try vk.endCommandBuffer(cb);
        }

        const present_signal: vk.SemaphoreSubmitInfo = .{ .semaphore = swapchain.semaphores[swapchain.index], .stageMask = .{ .blit = true } };
        const loop_signal: vk.SemaphoreSubmitInfo = .{ .semaphore = renderer.loop.handle, .stageMask = .{}, .value = renderer.loop.val };
        const submit_info2: vk.SubmitInfo2 = .{
            .waitSemaphoreInfoCount = 1,
            .pWaitSemaphoreInfos = &.{.{ .semaphore = renderer.fif_semaphores[renderer.fif_index], .stageMask = .{ .blit = true } }},
            .commandBufferInfoCount = 1,
            .pCommandBufferInfos = &.{.{ .commandBuffer = cb }},
            .signalSemaphoreInfoCount = 2,
            .pSignalSemaphoreInfos = &.{ present_signal, loop_signal },
        };
        try vk.queueSubmit2(renderer.ctx.queue, 1, @ptrCast(&submit_info2), null);
        renderer.fif_values[renderer.fif_index] = renderer.loop.val;
        renderer.fif_index = (renderer.fif_index + 1) % Renderer.max_frames;

        try swapchain.present(&renderer.ctx);

        if (swapchain.should_recreate) {
            swapchain.should_recreate = false;
            _ = sdl.getWindowSize(window, @ptrCast(&window_extent.width), @ptrCast(&window_extent.height));

            try vk.queueWaitIdle(renderer.ctx.queue);
            try swapchain.recreate(&renderer.ctx, window_extent);

            renderer.destroyTexture(offscreen_render);
            offscreen_render = try renderer.createTexture2D(.r16g16b16a16_unorm, window_extent, .{ .color_attachment = true, .transfer_src = true }, .{ .color = true });

            renderer.destroyTexture(triangle_id);
            triangle_id = try renderer.createTexture2D(.r32_uint, window_extent, .{ .color_attachment = true }, .{ .color = true });

            renderer.destroyTexture(depth_buffer);
            depth_buffer = try renderer.createTexture2D(.d32_sfloat, window_extent, .{ .depth_stencil_attachment = true }, .{ .depth = true });
        }
    }
    // arena_frame.deinit();

    try vk.deviceWaitIdle(renderer.ctx.device);
    const fframe: f32 = @floatFromInt(renderer.loop.val);
    log.info("avg_framtime: {}\tavg_diff from {}: {}", .{ frametime_acc / fframe, frametime_goal, diff_acc / fframe });
}

const quad_indices: [6]u32 = .{
    0, 1, 2,
    2, 3, 0,
};

const plane_vertices: [32]f32 = .{
    //pos              u    norm           v
    -10.0, 2.0, 10.0,  0.0, 0.0, 1.0, 0.0, 1.0,
    10.0,  2.0, 10.0,  1.0, 0.0, 1.0, 0.0, 1.0,
    10.0,  2.0, -10.0, 1.0, 0.0, 1.0, 0.0, 0.0,
    -10.0, 2.0, -10.0, 0.0, 0.0, 1.0, 0.0, 0.0,
};
