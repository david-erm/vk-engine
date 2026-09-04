const std = @import("std");
const log = std.log.scoped(.main);
const Io = std.Io;

const vk = @import("vk");
const shaders = @import("shaders");
const c = @import("c");

const vma = @import("vma.zig");
const zkf = @import("zkf.zig");
const sdl = @import("sdl.zig");
const math = @import("math.zig");

const gpu = @import("gfx/structs.zig");
const bufs = @import("gfx/buffers.zig");
const Swapchain = @import("gfx/Swapchain.zig");
const Gfx = @import("gfx/gfx.zig");

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

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var cam: zkf.Camera = .{};
    var gfx: Gfx = try .init(gpa);
    defer gfx.deinit(gpa);

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
    try vk.createSampler(gfx.ctx.device, &sampler_ci, null, &sampler);
    defer vk.destroySampler(gfx.ctx.device, sampler, null);

    const sampler_write: vk.WriteDescriptorSet = .{
        .dstSet = gfx.desc_man.set,
        .dstBinding = 2,
        .descriptorType = .sampler,
        .descriptorCount = 1,
        .dstArrayElement = 0,
        .pImageInfo = &.{.{
            .sampler = sampler,
        }},
    };
    vk.updateDescriptorSets(gfx.ctx.device, 1, @ptrCast(&sampler_write), 0, undefined);

    var window_extent: vk.Extent2D = .{ .width = 2560, .height = 1440 };
    const window = try sdl.createWindow("hello", @intCast(window_extent.width), @intCast(window_extent.height), .{
        .vulkan = true,
        .resizable = true,
        .fullscreen = true,
        .borderless = true,
    });

    //window? window owns input
    var mouse_mode = true;
    var mouse_pos: math.Vec2 = .{ .x = 0, .y = 0 };
    var mouse_state: sdl.MouseButtonFlags = .{};
    _ = sdl.setWindowRelativeMouseMode(window, true);
    var fullscreen = true;

    const surface = try sdl.vulkan.createSurface(window, gfx.ctx.instance, null);
    var swapchain: Swapchain = try .init(&gfx.ctx, gpa, surface, window_extent);
    defer swapchain.deinit(&gfx.ctx, gpa);

    var offscreen_render = try gfx.createTexture2D(
        .r16g16b16a16_unorm,
        window_extent,
        .{ .transfer_src = true, .storage = true, .transfer_dst = true },
        .{ .color = true },
    );
    defer gfx.destroyTexture(offscreen_render);

    var visbuffer = try gfx.createTexture2D(
        .r32_uint,
        window_extent,
        .{ .color_attachment = true, .sampled = true },
        .{ .color = true },
    );
    defer gfx.destroyTexture(visbuffer);
    try vk.nameHandle(gfx.ctx.device, visbuffer.handle, "Visbuffer");
    var visbuffer_idx = gfx.desc_man.appendSampled(gfx.ctx.device, visbuffer.view, .read_only_optimal);
    var offscreenrender_idx = gfx.desc_man.appendStorage(gfx.ctx.device, offscreen_render.view, .general);

    var depth_buffer = try gfx.createTexture2D(
        .d32_sfloat,
        window_extent,
        .{ .depth_stencil_attachment = true },
        .{ .depth = true },
    );
    defer gfx.destroyTexture(depth_buffer);

    var visbuffer_data: bufs.GpuMappedPush(math.UVec2) = try .init(
        gfx.ctx.vka,
        Gfx.max_frames,
        .{ .storage_buffer = true, .shader_device_address = true },
    );
    defer visbuffer_data.deinit(gfx.ctx.vka);

    //FIX: USE MATERIAL_SHADER_NUM
    var material_shader_dispatch_params: vk.Buffer = undefined;
    var material_shader_dispatch_alloc: vma.Allocation = undefined;
    defer vma.destroyBuffer(gfx.ctx.vka, material_shader_dispatch_params, material_shader_dispatch_alloc);
    {
        const ci: vk.BufferCreateInfo = .{
            .usage = .{ .indirect_buffer = true, .storage_buffer = true, .shader_device_address = true },
            //FIX: should share the material num here probably
            .size = @sizeOf(vk.DispatchIndirectCommand) * 2,
        };
        const aci: vma.AllocationCreateInfo = .{ .usage = .auto };
        try vma.createBuffer(gfx.ctx.vka, &ci, &aci, &material_shader_dispatch_params, &material_shader_dispatch_alloc, null);
    }

    var tile_offsets: vk.Buffer = undefined;
    var tile_offsets_alloc: vma.Allocation = undefined;
    const tile_offsets_num = 30_000;
    defer vma.destroyBuffer(gfx.ctx.vka, tile_offsets, tile_offsets_alloc);
    {
        const ci: vk.BufferCreateInfo = .{
            .usage = .{ .storage_buffer = true, .shader_device_address = true, .transfer_dst = true },
            .size = @sizeOf(math.UVec2) * tile_offsets_num,
        };
        const aci: vma.AllocationCreateInfo = .{ .usage = .auto };
        try vma.createBuffer(gfx.ctx.vka, &ci, &aci, &tile_offsets, &tile_offsets_alloc, null);
    }

    // const suzanne_pulled = try renderer.loadObj(a_static, &io, "assets/suzanne.obj");
    // const cube = try renderer.loadObj(a_static, &io, "assets/cube.obj");
    // const plane = asset.addMesh(&quad_indices, @ptrCast(&plane_vertices));

    // const icosphere = try renderer.loadGltf(io, gpa, "assets/icosphere/icosphere.gltf");
    // defer renderer.unloadModel(gpa, &icosphere);

    const helm = try gfx.loadGltf(io, gpa, "assets/DamagedHelmet/DamagedHelmet.gltf");
    defer gfx.unloadModel(gpa, &helm);

    const sponza = try gfx.loadGltf(io, gpa, "assets/Sponza/Sponza.gltf");
    defer gfx.unloadModel(gpa, &sponza);

    var skybox_pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(gfx.ctx.device, skybox_pipeline, null);
    {
        const skybox_module = try getShaderModule(gfx.ctx.device, shaders.skybox);
        defer vk.destroyShaderModule(gfx.ctx.device, skybox_module, null);
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
            .layout = gfx.graphics_layout,
        };
        try vk.createGraphicsPipelines(gfx.ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&skybox_pipeline));
    }

    var text_pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(gfx.ctx.device, text_pipeline, null);
    {
        const text_module = try getShaderModule(gfx.ctx.device, shaders.text);
        defer vk.destroyShaderModule(gfx.ctx.device, text_module, null);
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
            .layout = gfx.graphics_layout,
        };
        try vk.createGraphicsPipelines(gfx.ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&text_pipeline));
    }

    var visbuffer_pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(gfx.ctx.device, visbuffer_pipeline, null);
    {
        const visbuffer_module = try getShaderModule(gfx.ctx.device, shaders.fill);
        defer vk.destroyShaderModule(gfx.ctx.device, visbuffer_module, null);
        const stages: [2]vk.PipelineShaderStageCreateInfo = .{
            .{ .module = visbuffer_module, .pName = "main", .stage = .{ .vertex = true } },
            .{ .module = visbuffer_module, .pName = "main", .stage = .{ .fragment = true } },
        };
        const render_ci: vk.PipelineRenderingCreateInfo = .{
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = &.{.r32_uint},
            .depthAttachmentFormat = .d32_sfloat,
        };
        const blend_attachments = [_]vk.PipelineColorBlendAttachmentState{
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
            .layout = gfx.graphics_layout,
        };

        try vk.createGraphicsPipelines(gfx.ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&visbuffer_pipeline));
    }

    const ComputeShaders = enum {
        resolve,
        worklist,
    };
    var computes: std.EnumArray(ComputeShaders, vk.Pipeline) = .initUndefined();
    defer for (computes.values) |val| {
        vk.destroyPipeline(gfx.ctx.device, val, null);
    };
    inline for (@typeInfo(ComputeShaders).@"enum".field_names) |name| {
        const module = try getShaderModule(gfx.ctx.device, @field(shaders, name));
        defer vk.destroyShaderModule(gfx.ctx.device, module, null);
        const ci: vk.ComputePipelineCreateInfo = .{
            .layout = gfx.graphics_layout,
            .stage = .{ .stage = .{ .compute = true }, .module = module, .pName = "main" },
        };
        try vk.createComputePipelines(gfx.ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(computes.getPtr(@field(ComputeShaders, name))));
    }

    //basic dt and quit
    var last_time = Io.Clock.now(.real, io).toMicroseconds();
    var quit: bool = false;

    var sel: u32 = 0;

    //some stats
    var frametime_acc: f32 = 0;
    const frametime_goal = 8333;
    var diff_acc: f32 = 0;

    while (!quit) {
        const wait_info: vk.SemaphoreWaitInfo = .{
            .semaphoreCount = 1,
            .pSemaphores = @ptrCast(&gfx.loop.handle),
            .pValues = &.{gfx.fif_values[gfx.fif_index]},
        };
        try vk.waitSemaphores(gfx.ctx.device, &wait_info, std.math.maxInt(u64));
        gfx.loop.val += 1;
        const current_image = try swapchain.acquire(&gfx.ctx, gfx.fif_semaphores[gfx.fif_index]);

        //reduces input latency or smth
        // try Io.sleep(io, .fromMicroseconds(4000), .real);

        const elasped: f32 = @floatFromInt(Io.Clock.now(.real, io).toMicroseconds() - last_time);
        last_time = Io.Clock.now(.real, io).toMicroseconds();
        // const flast: f64 = @as(f64, @floatFromInt(last_time)) / 1_000_000;
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
            if (keyboard_state[@backingInt(sdl.Scancode.w)]) {
                in[0] = true;
            }
            if (keyboard_state[@backingInt(sdl.Scancode.s)]) {
                in[1] = true;
            }
            if (keyboard_state[@backingInt(sdl.Scancode.d)]) {
                in[2] = true;
            }
            if (keyboard_state[@backingInt(sdl.Scancode.a)]) {
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
        if (gfx.scene.offset == 2) {
            gfx.scene.reset();
            gfx.poses.reset();
            gfx.offsets.reset();
            visbuffer_data.reset();
        }

        gfx.scene.append(.{
            .projection = .perspective(cam.fov, aspect, 0.1, 32.0),
            .ortho = .ortho(0.0, @floatFromInt(window_extent.width), 0.0, @floatFromInt(window_extent.height)),
            .cam = cam.pose,
            .light_pos = .{
                .x = 0.0,
                .y = 5.0,
                .z = 0.0,
            },
            .dimensions = .{ .x = window_extent.width, .y = window_extent.height },
            .selected = sel,
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
        gfx.poses.appendSlice(&@as([25]zkf.Pose, @splat(.{})));
        // poses[4] = .{ .pos = .{ .x = 0, .y = -4, .z = 0 } };
        // poses_buffer[fif_index].write(0, poses);
        // poses_buffer[fif_index].write(4 * @sizeOf(Pose), .{ .pos = .{ .z = -2 } });

        var push: gpu.Push = .{
            .vertices = gfx.vertices.bda(gfx.ctx.device),
            .indices = gfx.indices.bda(gfx.ctx.device),
            .scene = gfx.scene.bda(gfx.ctx.device),
            .poses = gfx.poses.bda(gfx.ctx.device),
            .materials = gfx.materials.bda(gfx.ctx.device),
            .offsets = gfx.offsets.bda(gfx.ctx.device),
            .material_shader_params = vk.getBufferDeviceAddress(gfx.ctx.device, &.{ .buffer = material_shader_dispatch_params }),
            .user_buffer = @fromBackingInt(@intCast(0)),
            .tiles = vk.getBufferDeviceAddress(gfx.ctx.device, &.{ .buffer = tile_offsets }),
            .fif_index = @intCast(gfx.fif_index),
        };

        const cb: vk.CommandBuffer = gfx.cmdbuf[gfx.fif_index];
        try vk.resetCommandBuffer(cb, .{});

        {
            try vk.beginCommandBuffer(cb, &.{ .flags = .{ .one_time_submit = true } });

            // generate both barriers and rendering attachment info with some renderer call?
            const output_barriers = [_]vk.ImageMemoryBarrier2{
                .{
                    .srcStageMask = .{ .clear = true },
                    .srcAccessMask = .{},
                    .dstStageMask = .{ .clear = true },
                    .dstAccessMask = .{ .transfer_write = true },
                    .oldLayout = .undefined,
                    .newLayout = .general,
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
                    .image = visbuffer.handle,
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

            //VISBUFFER
            {
                const color_attach_infos = [_]vk.RenderingAttachmentInfo{
                    .{
                        .imageView = visbuffer.view,
                        .imageLayout = .attachment_optimal,
                        .loadOp = .clear,
                        .storeOp = .store,
                        .clearValue = .{ .color = .{ .uint32 = @splat(std.math.maxInt(u32)) } },
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

                vk.cmdBeginRendering(cb, &rendering_info);
                defer vk.cmdEndRendering(cb);
                const vp: vk.Viewport = .{
                    .width = @floatFromInt(window_extent.width),
                    .height = @as(f32, @floatFromInt(window_extent.height)),
                    .maxDepth = 1.0,
                    .minDepth = 0.0,
                };
                vk.cmdSetViewport(cb, 0, 1, @ptrCast(&vp));
                const scissor: vk.Rect2D = .{ .extent = window_extent };
                vk.cmdSetScissor(cb, 0, 1, @ptrCast(&scissor));

                vk.cmdBindPipeline(cb, .graphics, visbuffer_pipeline);
                vk.cmdBindIndexBuffer(cb, gfx.indices.handle(), 0, .uint32);
                vk.cmdBindDescriptorSets(cb, .graphics, gfx.graphics_layout, 0, 1, @ptrCast(&gfx.desc_man.set), 0, undefined);
                vk.cmdPushConstants(cb, gfx.graphics_layout, .{ .compute = true, .vertex = true }, 0, @sizeOf(gpu.Push), @ptrCast(&push));

                vk.cmdBeginDebugUtilsLabelEXT(cb, &.{ .pLabelName = "Visbuffer Fill" });

                //FIX:
                gfx.offsets.append(helm.meshes[0].offsets);
                vk.cmdDrawIndexed(cb, helm.meshes[0].offsets.index_count, 1, helm.meshes[0].offsets.start_index, helm.meshes[0].offsets.start_vertex, helm.meshes[0].material);

                //TODO: multiple meshes part of 1 model, how to resolve position then?
                for (sponza.meshes) |mesh| {
                    gfx.offsets.append(mesh.offsets);
                    vk.cmdDrawIndexed(cb, mesh.offsets.index_count, 1, mesh.offsets.start_index, mesh.offsets.start_vertex, mesh.material);
                }

                // vk.cmdEndDebugUtilsLabelEXT(cb);

                // vk.cmdBeginDebugUtilsLabelEXT(cb, &.{ .pLabelName = "Skybox" });

                // vk.cmdBindPipeline(cb, .graphics, skybox_pipeline);
                // vk.cmdDrawIndexed(cb, cube.offsets.index_count, 1, cube.offsets.start_index, cube.offsets.start_vertex, skybox_id);

                vk.cmdEndDebugUtilsLabelEXT(cb);
                // _ = cube;
                // _ = skybox_id;
            }

            vk.cmdBeginDebugUtilsLabelEXT(cb, &.{ .pLabelName = "Per Material Worklist generation" });
            vk.cmdBindPipeline(cb, .compute, computes.get(.worklist));
            vk.cmdBindDescriptorSets(cb, .compute, gfx.graphics_layout, 0, 1, @ptrCast(&gfx.desc_man.set), 0, undefined);
            visbuffer_data.append(.{ .x = visbuffer_idx, .y = offscreenrender_idx });
            push.user_buffer = visbuffer_data.bda(gfx.ctx.device);
            vk.cmdPushConstants(cb, gfx.graphics_layout, .{ .vertex = true, .compute = true }, 0, @sizeOf(gpu.Push), @ptrCast(&push));

            vk.cmdClearColorImage(
                cb,
                offscreen_render.handle,
                .general,
                &.{ .float32 = @splat(0.0) },
                1,
                &.{.{
                    .aspectMask = .{ .color = true },
                    .levelCount = 1,
                    .layerCount = 1,
                }},
            );
            vk.cmdFillBuffer(cb, tile_offsets, 0, 30_000 * @sizeOf(math.UVec2), 0);

            const compute_barriers = [_]vk.ImageMemoryBarrier2{
                .{
                    .srcStageMask = .{ .clear = true },
                    .srcAccessMask = .{ .transfer_write = true },
                    .dstStageMask = .{ .compute_shader = true },
                    .dstAccessMask = .{ .shader_storage_write = true },
                    .oldLayout = .general,
                    .newLayout = .general,
                    .image = offscreen_render.handle,
                    .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
                },
                .{
                    .srcStageMask = .{ .color_attachment_output = true },
                    .srcAccessMask = .{ .color_attachment_write = true },
                    .dstStageMask = .{ .compute_shader = true },
                    .dstAccessMask = .{ .shader_sampled_read = true },
                    .oldLayout = .attachment_optimal,
                    .newLayout = .read_only_optimal,
                    .image = visbuffer.handle,
                    .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
                },
            };
            vk.cmdPipelineBarrier2(cb, &.{ .imageMemoryBarrierCount = @intCast(compute_barriers.len), .pImageMemoryBarriers = @ptrCast(&compute_barriers) });

            //FIX: avoid dispatching more tiles than neccesary
            vk.cmdDispatch(cb, (window_extent.width / shaders.resolve.local_size[0]) + 1, (window_extent.height / shaders.resolve.local_size[1]) + 1, 1);

            vk.cmdEndDebugUtilsLabelEXT(cb);
            vk.cmdBeginDebugUtilsLabelEXT(cb, &.{ .pLabelName = "Material Dispatches" });
            const dispatch_params_barrier = [_]vk.BufferMemoryBarrier2{
                .{
                    .srcStageMask = .{ .compute_shader = true },
                    .srcAccessMask = .{ .shader_storage_write = true },
                    .dstStageMask = .{ .draw_indirect = true },
                    .dstAccessMask = .{ .indirect_command_read = true },
                    .buffer = material_shader_dispatch_params,
                    .size = vk.WholeSize,
                },
            };
            vk.cmdPipelineBarrier2(cb, &.{ .bufferMemoryBarrierCount = @intCast(dispatch_params_barrier.len), .pBufferMemoryBarriers = @ptrCast(&dispatch_params_barrier) });

            vk.cmdBindPipeline(cb, .compute, computes.get(.resolve));
            vk.cmdDispatchIndirect(cb, material_shader_dispatch_params, @sizeOf(vk.DispatchIndirectCommand));

            vk.cmdEndDebugUtilsLabelEXT(cb);

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
        const loop_signal: vk.SemaphoreSubmitInfo = .{ .semaphore = gfx.loop.handle, .stageMask = .{}, .value = gfx.loop.val };
        const submit_info2: vk.SubmitInfo2 = .{
            .waitSemaphoreInfoCount = 1,
            .pWaitSemaphoreInfos = &.{.{ .semaphore = gfx.fif_semaphores[gfx.fif_index], .stageMask = .{ .blit = true } }},
            .commandBufferInfoCount = 1,
            .pCommandBufferInfos = &.{.{ .commandBuffer = cb }},
            .signalSemaphoreInfoCount = 2,
            .pSignalSemaphoreInfos = &.{ present_signal, loop_signal },
        };
        try vk.queueSubmit2(gfx.ctx.queue, 1, @ptrCast(&submit_info2), null);
        gfx.fif_values[gfx.fif_index] = gfx.loop.val;
        gfx.fif_index = (gfx.fif_index + 1) % Gfx.max_frames;

        try swapchain.present(&gfx.ctx);

        if (swapchain.should_recreate) {
            swapchain.should_recreate = false;
            _ = sdl.getWindowSize(window, @ptrCast(&window_extent.width), @ptrCast(&window_extent.height));

            try vk.queueWaitIdle(gfx.ctx.queue);
            try swapchain.recreate(&gfx.ctx, window_extent);

            //FIX can we have a recreate method or smth?
            gfx.destroyTexture(offscreen_render);
            offscreen_render = try gfx.createTexture2D(
                .r16g16b16a16_unorm,
                window_extent,
                .{ .storage = true, .transfer_src = true, .transfer_dst = true },
                .{ .color = true },
            );

            gfx.destroyTexture(visbuffer);
            visbuffer = try gfx.createTexture2D(
                .r32_uint,
                window_extent,
                .{ .color_attachment = true, .sampled = true },
                .{ .color = true },
            );

            //FIX:
            visbuffer_idx = gfx.desc_man.appendSampled(gfx.ctx.device, visbuffer.view, .read_only_optimal);
            offscreenrender_idx = gfx.desc_man.appendStorage(gfx.ctx.device, offscreen_render.view, .general);

            gfx.destroyTexture(depth_buffer);
            depth_buffer = try gfx.createTexture2D(.d32_sfloat, window_extent, .{ .depth_stencil_attachment = true }, .{ .depth = true });
        }
    }
    // arena_frame.deinit();

    try vk.deviceWaitIdle(gfx.ctx.device);
    const fframe: f32 = @floatFromInt(gfx.loop.val);
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
