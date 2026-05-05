const std = @import("std");
const Io = std.Io;
const log = std.log.scoped(.howtovulkan);

const vk = @import("vk");
const shaders = @import("shaders");

const zkf = @import("helpers.zig");
const sdl = @import("sdl.zig");
const vma = @import("vma.zig");
const ktx = @import("ktx.zig");

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
    cam: Pose = .{},
    poses: [5]Pose = @splat(.{}),
    light_pos: Vec4 = .{ .x = 0.0, .y = -4.0, .z = 3.0, .w = 0.0 },
    selected: u32 = 1,
};

const max_frames = 2;
var cam: Camera = .{ .pose = .{ .pos = .{ .z = 6.0 }, .rot = .identity, .extra = 0 } };
var fullscreen = false;
var mouse_mode = true;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    var io = init.io;

    var ctx: zkf.Context = try .init(arena);
    defer ctx.deinit();
    var rctx: zkf.RenderContext = try .init(&ctx, arena, 800, 600, "testing", max_frames);
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

    var commandPool: vk.CommandPool = undefined;
    var command_buffers: [max_frames]vk.CommandBuffer = undefined;
    defer vk.destroyCommandPool(ctx.device, commandPool, null);
    {
        const commandPoolCI: vk.CommandPoolCreateInfo = .{ .flags = .{ .reset_command_buffer = true }, .queueFamilyIndex = ctx.qfamily };
        try vk.createCommandPool(ctx.device, &commandPoolCI, null, &commandPool);
        const cmdBufferCI: vk.CommandBufferAllocateInfo = .{ .commandPool = commandPool, .commandBufferCount = max_frames, .level = .primary };
        try vk.allocateCommandBuffers(ctx.device, &cmdBufferCI, &command_buffers);
    }

    var texture_descriptors: [4]vk.DescriptorImageInfo = undefined;

    const skybox = try zkf.loadImage(arena, "assets/skybox.ktx2", ctx.device, ctx.vka, ctx.queue, commandPool);
    defer vma.destroyImage(ctx.vka, skybox.image, skybox.alon);
    defer vk.destroyImageView(ctx.device, skybox.view, null);
    defer vk.destroySampler(ctx.device, skybox.sampler, null);
    texture_descriptors[3].imageLayout = .read_only_optimal;
    texture_descriptors[3].sampler = skybox.sampler;
    texture_descriptors[3].imageView = skybox.view;

    //textures
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

    var desc_layout: vk.DescriptorSetLayout = undefined;
    defer vk.destroyDescriptorSetLayout(ctx.device, desc_layout, null);
    {
        const desc_flags: vk.DescriptorBindingFlags = .{ .variable_descriptor_count = false, .update_after_bind = true };
        const desc_bind_flags: vk.DescriptorSetLayoutBindingFlagsCreateInfo = .{ .pBindingFlags = @ptrCast(&desc_flags), .bindingCount = 1 };
        const desc_layout_bind_tex: vk.DescriptorSetLayoutBinding = .{
            .binding = 0,
            .stageFlags = .{ .fragment = true },
            .descriptorType = .combined_image_sampler,
            .descriptorCount = @intCast(texture_descriptors.len),
        };
        const desc_layout_ci: vk.DescriptorSetLayoutCreateInfo = .{
            .pNext = &desc_bind_flags,
            .pBindings = @ptrCast(&desc_layout_bind_tex),
            .bindingCount = 1,
            .flags = .{ .update_after_bind_pool = true },
        };
        try vk.createDescriptorSetLayout(ctx.device, &desc_layout_ci, null, &desc_layout);
    }

    var desc_pool: vk.DescriptorPool = undefined;
    defer vk.destroyDescriptorPool(ctx.device, desc_pool, null);
    {
        const pool_size: vk.DescriptorPoolSize = .{ .descriptorCount = @intCast(texture_descriptors.len), .type = .combined_image_sampler };
        const pool_ci: vk.DescriptorPoolCreateInfo = .{ .maxSets = 1, .poolSizeCount = 1, .pPoolSizes = @ptrCast(&pool_size), .flags = .{ .update_after_bind = true } };
        try vk.createDescriptorPool(ctx.device, &pool_ci, null, &desc_pool);
    }

    var desc_set: vk.DescriptorSet = undefined;
    {
        const counts: u32 = @intCast(texture_descriptors.len);
        const set_vai: vk.DescriptorSetVariableDescriptorCountAllocateInfo = .{
            .pDescriptorCounts = @ptrCast(&counts),
            .descriptorSetCount = 1,
        };
        const set_ai: vk.DescriptorSetAllocateInfo = .{
            .descriptorPool = desc_pool,
            .descriptorSetCount = 1,
            .pSetLayouts = @ptrCast(&desc_layout),
            .pNext = &set_vai,
        };
        try vk.allocateDescriptorSets(ctx.device, &set_ai, @ptrCast(&desc_set));

        const write_desc_set: vk.WriteDescriptorSet = .{
            .descriptorCount = counts,
            .descriptorType = .combined_image_sampler,
            .dstBinding = 0,
            .dstSet = desc_set,
            .pImageInfo = &texture_descriptors,
        };
        vk.updateDescriptorSets(ctx.device, 1, @ptrCast(&write_desc_set), 0, undefined);
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

    var skybox_layout: vk.PipelineLayout = undefined;
    defer vk.destroyPipelineLayout(ctx.device, skybox_layout, null);
    {
        const ci: vk.PipelineLayoutCreateInfo = .{
            .pushConstantRangeCount = shaders.skybox.push_constant_ranges.len,
            .pPushConstantRanges = &shaders.skybox.push_constant_ranges,
            .setLayoutCount = 1,
            .pSetLayouts = @ptrCast(&desc_layout),
        };
        try vk.createPipelineLayout(ctx.device, &ci, null, &skybox_layout);
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
            .layout = skybox_layout,
        };
        try vk.createGraphicsPipelines(ctx.device, null, 1, @ptrCast(&ci), null, @ptrCast(&skybox_pipeline));
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

    var last_time = Io.Clock.now(.real, io).toMicroseconds();
    var quit: bool = false;
    var frame_index: usize = 0;
    var image_index: u32 = 0;
    var recreate_swap: bool = false;
    var sel: u32 = 0;
    var last_quat: Quat = .identity;
    var shader_data: ShaderData = .{};
    while (!quit) {
        try vk.waitForFences(ctx.device, 1, @ptrCast(&rctx.fences[frame_index]), .True, std.math.maxInt(u64));
        try vk.resetFences(ctx.device, 1, @ptrCast(&rctx.fences[frame_index]));
        const elasped: f32 = @floatFromInt(Io.Clock.now(.real, io).toMicroseconds() - last_time);
        last_time = Io.Clock.now(.real, io).toMicroseconds();
        const dT = elasped / 1000000.0;

        // log.info("fps: {}", .{1 / dT});

        vk.acquireNextImageKHR(ctx.device, rctx.swapchain, std.math.maxInt(u64), rctx.present_semaphores[frame_index], null, &image_index) catch |e| switch (e) {
            error.error_out_of_dateKHR, error.suboptimalKHR => recreate_swap = true,
            else => return e,
        };

        const aspect = @as(f32, @floatFromInt(rctx.windowsize.width)) / @as(f32, @floatFromInt(rctx.windowsize.height));
        last_quat = last_quat.mul(.fromAngleAxis(std.math.pi * 0.5 * dT, .{ .y = 1 })).normalize();

        shader_data.projection = .perspective(cam.fov, aspect, 0.1, 32.0);
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

        shader_buffers[frame_index].write(0, shader_data);

        const cb: vk.CommandBuffer = command_buffers[frame_index];
        try vk.resetCommandBuffer(cb, .{});

        {
            try vk.beginCommandBuffer(cb, &.{ .flags = .{ .one_time_submit = true } });

            const output_barriers: [2]vk.ImageMemoryBarrier2 = .{ .{
                .srcStageMask = .{ .color_attachment_output = true },
                .srcAccessMask = .{},
                .dstStageMask = .{ .color_attachment_output = true },
                .dstAccessMask = .{ .color_attachment_read = true, .color_attachment_write = true },
                .oldLayout = .undefined,
                .newLayout = .attachment_optimal,
                .image = rctx.sc_imgs[image_index],
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
                .imageView = rctx.sc_img_views[image_index],
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
                vk.cmdPushConstants(cb, pipeline_layout, .{ .vertex = true }, 0, @sizeOf(vk.DeviceAddress), std.mem.asBytes(&shader_buffers[frame_index].address(ctx.device)));

                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&suzanne_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, suzanne_buffer.handle, vBufferSize, .uint32);
                vk.cmdDrawIndexed(cb, @intCast(suzanne.indices.items.len), 3, 0, 0, 0);

                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&plane_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, plane_buffer.handle, @sizeOf(f32) * plane_vertices.len, .uint16);
                vk.cmdDrawIndexed(cb, @intCast(quad_indices.len), 1, 0, 0, 3);

                vk.cmdBindPipeline(cb, .graphics, skybox_pipeline);
                vk.cmdBindDescriptorSets(cb, .graphics, skybox_layout, 0, 1, @ptrCast(&desc_set), 0, undefined);
                vk.cmdPushConstants(cb, skybox_layout, .{ .vertex = true }, 0, @sizeOf(vk.DeviceAddress), std.mem.asBytes(&shader_buffers[frame_index].address(ctx.device)));

                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&cube_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, cube_buffer.handle, @sizeOf(Vertex) * cube.vertices.items.len, .uint32);
                vk.cmdDrawIndexed(cb, @intCast(cube.indices.items.len), 1, 0, 0, 0);
            }

            const present_barrier: vk.ImageMemoryBarrier2 = .{
                .srcStageMask = .{ .color_attachment_output = true },
                .srcAccessMask = .{ .color_attachment_write = true },
                .dstStageMask = .{ .color_attachment_output = true },
                .dstAccessMask = .{},
                .oldLayout = .attachment_optimal,
                .newLayout = .present_srcKHR,
                .image = rctx.sc_imgs[image_index],
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
            };
            vk.cmdPipelineBarrier2(cb, &.{ .imageMemoryBarrierCount = 1, .pImageMemoryBarriers = @ptrCast(&present_barrier) });

            try vk.endCommandBuffer(cb);
        }

        const submit_info: vk.SubmitInfo = .{
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = @ptrCast(&rctx.present_semaphores[frame_index]),
            .pWaitDstStageMask = &.{.{ .color_attachment_output = true }},
            .commandBufferCount = 1,
            .pCommandBuffers = @ptrCast(&cb),
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = @ptrCast(&rctx.render_semaphores[image_index]),
        };
        try vk.queueSubmit(ctx.queue, 1, @ptrCast(&submit_info), rctx.fences[frame_index]);

        frame_index = (frame_index + 1) % max_frames;

        const present_info: vk.PresentInfoKHR = .{
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = @ptrCast(&rctx.render_semaphores[image_index]),
            .swapchainCount = 1,
            .pSwapchains = @ptrCast(&rctx.swapchain),
            .pImageIndices = @ptrCast(&image_index),
        };

        vk.queuePresentKHR(ctx.queue, &present_info) catch |e| switch (e) {
            error.error_out_of_dateKHR, error.suboptimalKHR => recreate_swap = true,
            else => return e,
        };

        //input
        {
            if (mouse_mode) {
                var xrel: f32 = 0;
                var yrel: f32 = 0;
                _ = sdl.getRelativeMouseState(&xrel, &yrel);
                cam.mouseInput(xrel, yrel);
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
                                .h => sel = 2,
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

        if (recreate_swap) {
            recreate_swap = false;
            try rctx.recreate_swap(&ctx);
        }
    }

    try vk.deviceWaitIdle(ctx.device);
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
