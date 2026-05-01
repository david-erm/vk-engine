const std = @import("std");
const Io = std.Io;
const log = std.log.scoped(.howtovulkan);

const zkf = @import("helpers.zig");
const vk = @import("vk.zig");
const sdl = @import("sdl.zig");
const vma = @import("vma.zig");
const ktx = @import("ktx.zig");

const shader align(@alignOf(u32)) = @embedFile("shader").*;

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
    pos: [3]Vec4 = @splat(.{}),
    quat: Quat = .identity,
    light_pos: Vec4 = .{ .x = 0.0, .y = -4.0, .z = 3.0, .w = 0.0 },
    selected: u32 = 1,
};

const max_frames = 2;
var windowsize: vk.Extent2D = .{ .width = 800, .height = 600 };
var cam: Camera = .{ .pose = .{ .pos = .{ .z = 6.0 }, .rot = .identity } };

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    var io = init.io;

    try sdl.init(.{ .video = true });
    defer sdl.deinit();
    try sdl.vulkan.loadLibrary(null);
    const instanceProcAddr = sdl.vulkan.getInstanceProcAddr();

    vk.load(instanceProcAddr);

    var instance: vk.Instance = undefined;
    defer vk.destroyInstance(instance, null);
    {
        const instance_extensions = try sdl.vulkan.getInstanceExtensions();
        for (instance_extensions) |extension| {
            log.debug("instance extension: {s}", .{extension});
        }
        const app_info: vk.ApplicationInfo = .{
            .pApplicationName = "howtovulkna",
            .apiVersion = vk.makeApiVersion(0, 1, 3, 0),
        };
        try vk.createInstance(&.{
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = @intCast(instance_extensions.len),
            .ppEnabledExtensionNames = instance_extensions.ptr,
        }, null, &instance);
        vk.loadInstance(instance);
    }

    var pdevice: vk.PhysicalDevice = undefined;
    {
        var device_count: u32 = 0;
        try vk.enumeratePhysicalDevices(instance, &device_count, null);
        const devices = try arena.alloc(vk.PhysicalDevice, device_count);
        try vk.enumeratePhysicalDevices(instance, &device_count, devices.ptr);
        const device_index: u32 = 0;
        pdevice = devices[device_index];
        for (devices) |d| {
            var dp: vk.PhysicalDeviceProperties2 = .{};
            vk.getPhysicalDeviceProperties2(d, &dp);
            log.info("dev: {s}", .{dp.properties.deviceName});
        }

        var device_properties: vk.PhysicalDeviceProperties2 = .{};
        vk.getPhysicalDeviceProperties2(devices[device_index], &device_properties);
        log.info("Selected device: {s}", .{device_properties.properties.deviceName});
    }

    var queue_family: u32 = 0;
    {
        var queue_count: u32 = 0;
        vk.getPhysicalDeviceQueueFamilyProperties(pdevice, &queue_count, null);
        const queue_families = try arena.alloc(vk.QueueFamilyProperties, queue_count);
        vk.getPhysicalDeviceQueueFamilyProperties(pdevice, &queue_count, queue_families.ptr);
        while (!queue_families[queue_family].queueFlags.graphics) : (queue_family += 1) {}
        try sdl.vulkan.getPresentationSupport(instance, pdevice, queue_family);
    }

    var device: vk.Device = undefined;
    defer vk.destroyDevice(device, null);
    var queue: vk.Queue = undefined;
    {
        const qfpriorities: [1]f32 = .{1.0};
        const queueCI: vk.DeviceQueueCreateInfo = .{
            .queueFamilyIndex = queue_family,
            .queueCount = 1,
            .pQueuePriorities = &qfpriorities,
        };
        var enableVK12Features: vk.PhysicalDeviceVulkan12Features = .{
            .descriptorIndexing = .True,
            .shaderSampledImageArrayNonUniformIndexing = .True,
            .descriptorBindingVariableDescriptorCount = .True,
            .runtimeDescriptorArray = .True,
            .bufferDeviceAddress = .True,
        };
        var enableVK13Features: vk.PhysicalDeviceVulkan13Features = .{
            .pNext = &enableVK12Features,
            .synchronization2 = .True,
            .dynamicRendering = .True,
        };
        try vk.createDevice(pdevice, &.{
            .pNext = &enableVK13Features,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = @ptrCast(&queueCI),
            .enabledExtensionCount = 1,
            .ppEnabledExtensionNames = &.{"VK_KHR_swapchain"},
            .pEnabledFeatures = &.{ .samplerAnisotropy = .True },
        }, null, &device);
        vk.loadDevice(device);
        vk.getDeviceQueue(device, queue_family, 0, &queue);
    }

    var alloc: vma.Allocator = undefined;
    defer vma.destroyAllocator(alloc);
    {
        const vkFuncs: vma.VulkanFunctions = .{
            .vkGetInstanceProcAddr = vk.table.instance.vkGetInstanceProcAddr,
            .vkGetDeviceProcAddr = vk.table.device.vkGetDeviceProcAddr,
            .vkCreateImage = vk.table.device.vkCreateImage,
        };
        _ = vma.createAllocator(&.{
            .flags = .{ .BufferDeviceAddressBit = 1 },
            .physicalDevice = pdevice,
            .device = device,
            .pVulkanFunctions = &vkFuncs,
            .instance = instance,
        }, &alloc);
    }

    var window = try sdl.createWindow("How to vulkan", @intCast(windowsize.width), @intCast(windowsize.height), .{
        .vulkan = true,
        .resizable = true,
        .fullscreen = true,
    });
    defer sdl.destroyWindow(&window);
    _ = sdl.setWindowRelativeMouseMode(window, true);
    const surface = try sdl.vulkan.createSurface(window, instance, null);
    defer vk.destroySurfaceKHR(instance, surface, null);

    var swapchain: vk.SwapchainKHR = undefined;
    defer vk.destroySwapchainKHR(device, swapchain, null);
    const image_format: vk.Format = .b8g8r8a8_srgb;
    var swapchain_ci: vk.SwapchainCreateInfoKHR = undefined;
    {
        var surfaceCaps: vk.SurfaceCapabilitiesKHR = undefined;
        try vk.getPhysicalDeviceSurfaceCapabilitiesKHR(pdevice, surface, &surfaceCaps);
        swapchain_ci = .{
            .surface = surface,
            .minImageCount = surfaceCaps.minImageCount,
            .imageFormat = image_format,
            .imageColorSpace = .srgb_nonlinear,
            .imageExtent = windowsize,
            .imageArrayLayers = 1,
            .imageUsage = .{ .color_attachment = true },
            .preTransform = .{ .identity = true },
            .compositeAlpha = .{ .@"opaque" = true },
            .presentMode = .fifo,
        };
        try vk.createSwapchainKHR(device, &swapchain_ci, null, &swapchain);
    }

    var images: []vk.Image = undefined;
    var image_views: []vk.ImageView = undefined;
    var image_count: u32 = 0;
    defer for (image_views) |view| {
        vk.destroyImageView(device, view, null);
    };
    {
        try vk.getSwapchainImagesKHR(device, swapchain, &image_count, null);
        images = try arena.alloc(vk.Image, image_count);
        try vk.getSwapchainImagesKHR(device, swapchain, &image_count, images.ptr);

        image_views = try arena.alloc(vk.ImageView, images.len);
        for (0..images.len) |i| {
            const image_viewCI: vk.ImageViewCreateInfo = .{
                .image = images[i],
                .viewType = .@"2d",
                .format = image_format,
                .subresourceRange = .{
                    .aspectMask = .{ .color = true },
                    .layerCount = 1,
                    .levelCount = 1,
                },
            };
            try vk.createImageView(device, &image_viewCI, null, &image_views[i]);
        }
    }

    var depth_format: vk.Format = .undefined;
    var depth_image: vk.Image = undefined;
    var depth_imageCI: vk.ImageCreateInfo = undefined;
    var depth_image_alloc: vma.Allocation = undefined;
    defer vma.destroyImage(alloc, depth_image, depth_image_alloc);
    var depth_image_view: vk.ImageView = undefined;
    defer vk.destroyImageView(device, depth_image_view, null);
    {
        const depth_formats: [2]vk.Format = .{ .d32_sfloat_s8_uint, .d24_unorm_s8_uint };
        for (depth_formats) |format| {
            var formatProperties: vk.FormatProperties2 = .{ .formatProperties = .{} };
            vk.getPhysicalDeviceFormatProperties2(pdevice, format, &formatProperties);
            if (formatProperties.formatProperties.optimalTilingFeatures.depth_stencil_attachment) {
                depth_format = format;
                break;
            }
        }
        std.debug.assert(depth_format != vk.Format.undefined);
        depth_imageCI = .{
            .extent = .{ .width = windowsize.width, .height = windowsize.height, .depth = 1 },
            .arrayLayers = 1,
            .mipLevels = 1,
            .format = depth_format,
            .imageType = .@"2d",
            .initialLayout = .undefined,
            .tiling = .optimal,
            .usage = .{ .depth_stencil_attachment = true },
            .samples = .{ .@"1" = true },
        };
        const allocCI: vma.AllocationCreateInfo = .{ .usage = .auto };
        _ = vma.createImage(alloc, &depth_imageCI, &allocCI, &depth_image, &depth_image_alloc, null);

        const depthImageViewCI: vk.ImageViewCreateInfo = .{
            .format = depth_format,
            .viewType = .@"2d",
            .image = depth_image,
            .subresourceRange = .{
                .aspectMask = .{ .depth = true },
                .layerCount = 1,
                .levelCount = 1,
            },
        };
        try vk.createImageView(device, &depthImageViewCI, null, &depth_image_view);
    }

    const suzanne = try zkf.loadObj(arena, &io, "assets/suzanne.obj");

    const vBufferSize: vk.DeviceSize = @sizeOf(Vertex) * suzanne.vertices.items.len;
    const iBufferSize: vk.DeviceSize = @sizeOf(u16) * suzanne.indices.items.len;
    const suzanne_buffer = zkf.Buffer.init(alloc, .{ .size = vBufferSize + iBufferSize, .usage = .{ .index_buffer = true, .vertex_buffer = true } }, .mapped_vram);
    defer suzanne_buffer.deinit(alloc);
    suzanne_buffer.write(0, suzanne.vertices.items);
    suzanne_buffer.write(vBufferSize, suzanne.indices.items);

    const plane_buffer = zkf.Buffer.init(alloc, .{
        .size = @sizeOf(f32) * plane_vertices.len + @sizeOf(u16) * quad_indices.len,
        .usage = .{ .index_buffer = true, .vertex_buffer = true },
    }, .mapped_vram);
    defer plane_buffer.deinit(alloc);
    plane_buffer.write(0, plane_vertices);
    plane_buffer.write(128, quad_indices);

    var fences: [max_frames]vk.Fence = undefined;
    var presentSmp: [max_frames]vk.Semaphore = undefined;
    var renderSmp: []vk.Semaphore = undefined;
    defer for (fences, presentSmp) |fence, smp| {
        vk.destroySemaphore(device, smp, null);
        vk.destroyFence(device, fence, null);
    };
    defer for (renderSmp) |semaphore| {
        vk.destroySemaphore(device, semaphore, null);
    };
    {
        const fenceCI: vk.FenceCreateInfo = .{ .flags = .{ .signaled = true } };
        const semaphoreCI: vk.SemaphoreCreateInfo = .{};
        for (0..max_frames) |i| {
            try vk.createFence(device, &fenceCI, null, &fences[i]);
            try vk.createSemaphore(device, &.{}, null, &presentSmp[i]);
        }
        renderSmp = try arena.alloc(vk.Semaphore, images.len);
        for (renderSmp) |*semaphore| {
            try vk.createSemaphore(device, &semaphoreCI, null, semaphore);
        }
    }

    var commandPool: vk.CommandPool = undefined;
    var command_buffers: [max_frames]vk.CommandBuffer = undefined;
    defer vk.destroyCommandPool(device, commandPool, null);
    {
        const commandPoolCI: vk.CommandPoolCreateInfo = .{ .flags = .{ .reset_command_buffer = true }, .queueFamilyIndex = queue_family };
        try vk.createCommandPool(device, &commandPoolCI, null, &commandPool);
        const cmdBufferCI: vk.CommandBufferAllocateInfo = .{ .commandPool = commandPool, .commandBufferCount = max_frames, .level = .primary };
        try vk.allocateCommandBuffers(device, &cmdBufferCI, &command_buffers);
    }

    //textures
    var texture_descriptors: [3]vk.DescriptorImageInfo = undefined;
    var textures: [3]Texture = undefined;
    defer for (textures) |texture| {
        vk.destroySampler(device, texture.sampler, null);
        vk.destroyImageView(device, texture.view, null);
        vma.destroyImage(alloc, texture.image, texture.alon);
    };
    for (&textures, 0..) |*texture, i| {
        var buf: [128]u8 = @splat(0);
        const filename = try std.fmt.bufPrintSentinel(&buf, "assets/suzanne{}.ktx", .{i}, 0);

        texture.* = try zkf.loadImage(arena, filename, device, alloc, queue, commandPool);

        texture_descriptors[i] = .{
            .sampler = texture.sampler,
            .imageView = texture.view,
            .imageLayout = .read_only_optimal,
        };
    }

    var desc_layout: vk.DescriptorSetLayout = undefined;
    defer vk.destroyDescriptorSetLayout(device, desc_layout, null);
    {
        const desc_flags: vk.DescriptorBindingFlags = .{ .variable_descriptor_count = true };
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
        };
        try vk.createDescriptorSetLayout(device, &desc_layout_ci, null, &desc_layout);
    }

    var desc_pool: vk.DescriptorPool = undefined;
    defer vk.destroyDescriptorPool(device, desc_pool, null);
    {
        const pool_size: vk.DescriptorPoolSize = .{ .descriptorCount = @intCast(texture_descriptors.len), .type = .combined_image_sampler };
        const pool_ci: vk.DescriptorPoolCreateInfo = .{ .maxSets = 1, .poolSizeCount = 1, .pPoolSizes = @ptrCast(&pool_size) };
        try vk.createDescriptorPool(device, &pool_ci, null, &desc_pool);
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
        try vk.allocateDescriptorSets(device, &set_ai, @ptrCast(&desc_set));

        const write_desc_set: vk.WriteDescriptorSet = .{
            .descriptorCount = counts,
            .descriptorType = .combined_image_sampler,
            .dstBinding = 0,
            .dstSet = desc_set,
            .pImageInfo = &texture_descriptors,
        };
        vk.updateDescriptorSets(device, 1, @ptrCast(&write_desc_set), 0, undefined);
    }

    var pipeline_layout: vk.PipelineLayout = undefined;
    defer vk.destroyPipelineLayout(device, pipeline_layout, null);
    {
        const pc_range: vk.PushConstantRange = .{
            .offset = 0,
            .size = @sizeOf(vk.DeviceAddress),
            .stageFlags = .{ .vertex = true },
        };
        const ci: vk.PipelineLayoutCreateInfo = .{
            .pushConstantRangeCount = 1,
            .pPushConstantRanges = @ptrCast(&pc_range),
            .setLayoutCount = 1,
            .pSetLayouts = @ptrCast(&desc_layout),
        };
        try vk.createPipelineLayout(device, &ci, null, &pipeline_layout);
    }

    var shader_module: vk.ShaderModule = undefined;
    defer vk.destroyShaderModule(device, shader_module, null);
    {
        const module_ci: vk.ShaderModuleCreateInfo = .{ .pCode = @ptrCast(&shader), .codeSize = shader.len };
        try vk.createShaderModule(device, &module_ci, null, &shader_module);
    }

    var pipeline: vk.Pipeline = undefined;
    defer vk.destroyPipeline(device, pipeline, null);
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
            .{ .stage = .{ .vertex = true }, .module = shader_module, .pName = "main" },
            .{ .stage = .{ .fragment = true }, .module = shader_module, .pName = "main" },
        };
        const render_ci: vk.PipelineRenderingCreateInfo = .{
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = @ptrCast(&image_format),
            .depthAttachmentFormat = depth_format,
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
        try vk.createGraphicsPipelines(device, null, 1, @ptrCast(&ci), null, @ptrCast(&pipeline));
    }

    var shader_buffers: [max_frames]zkf.Buffer = undefined;
    defer for (shader_buffers) |buffer| {
        buffer.deinit(alloc);
    };
    for (0..max_frames) |i| {
        const uBufferCI: vk.BufferCreateInfo = .{
            .size = @sizeOf(ShaderData),
            .usage = .{ .shader_device_address = true },
        };
        shader_buffers[i] = .init(alloc, uBufferCI, .mapped_vram);
    }

    var last_time = Io.Clock.now(.real, io).toMicroseconds();
    var quit: bool = false;
    var frame_index: usize = 0;
    var image_index: u32 = 0;
    var recreate_swap: bool = false;
    var sel: u32 = 0;
    var last_quat: Quat = .identity;
    while (!quit) {
        try vk.waitForFences(device, 1, @ptrCast(&fences[frame_index]), .True, std.math.maxInt(u64));
        try vk.resetFences(device, 1, @ptrCast(&fences[frame_index]));
        const elasped: f32 = @floatFromInt(Io.Clock.now(.real, io).toMicroseconds() - last_time);
        last_time = Io.Clock.now(.real, io).toMicroseconds();
        const dT = elasped / 1000000.0;

        vk.acquireNextImageKHR(device, swapchain, std.math.maxInt(u64), presentSmp[frame_index], null, &image_index) catch |e| switch (e) {
            error.error_out_of_dateKHR, error.suboptimalKHR => recreate_swap = true,
            else => return e,
        };

        const aspect = @as(f32, @floatFromInt(windowsize.width)) / @as(f32, @floatFromInt(windowsize.height));
        last_quat = last_quat.mul(.fromAngleAxis(std.math.pi * 0.5 * dT, .{ .y = 1 })).normalize();
        var shader_data: ShaderData = .{
            .projection = .perspective(std.math.degreesToRadians(60.0), aspect, 0.1, 32.0),
            .cam = cam.pose,
            .selected = sel,
            .quat = last_quat,
        };
        for (0..3) |i| {
            const idx: f32 = @floatFromInt(i);
            const pos: Vec3 = .{ .x = (idx - 1.0) * 3.0, .y = -(idx), .z = 0.0 };
            shader_data.pos[i] = .vec4(pos, 0);
        }
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
                .image = images[image_index],
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .levelCount = 1, .layerCount = 1 },
            }, .{
                .srcStageMask = .{ .late_fragment_tests = true },
                .srcAccessMask = .{ .depth_stencil_attachment_write = true },
                .dstStageMask = .{ .early_fragment_tests = true },
                .dstAccessMask = .{ .depth_stencil_attachment_write = true },
                .oldLayout = .undefined,
                .newLayout = .attachment_optimal,
                .image = depth_image,
                .subresourceRange = .{ .aspectMask = .{ .depth = true, .stencil = true }, .levelCount = 1, .layerCount = 1 },
            } };
            vk.cmdPipelineBarrier2(cb, &.{ .imageMemoryBarrierCount = 2, .pImageMemoryBarriers = &output_barriers });

            const color_attach_info: vk.RenderingAttachmentInfo = .{
                .imageView = image_views[image_index],
                .imageLayout = .attachment_optimal,
                .loadOp = .clear,
                .storeOp = .store,
                .clearValue = .{ .color = .{ .float32 = .{ 0.0, 0.0, 0.0, 1.0 } } },
            };
            const depth_attach_info: vk.RenderingAttachmentInfo = .{
                .imageView = depth_image_view,
                .imageLayout = .attachment_optimal,
                .loadOp = .clear,
                .storeOp = .dont_care,
                .clearValue = .{ .depthStencil = .{ .depth = 1.0, .stencil = 0 } },
            };

            const rendering_info: vk.RenderingInfo = .{
                .renderArea = .{ .extent = windowsize },
                .layerCount = 1,
                .colorAttachmentCount = 1,
                .pColorAttachments = @ptrCast(&color_attach_info),
                .pDepthAttachment = &depth_attach_info,
            };

            {
                vk.cmdBeginRendering(cb, &rendering_info);
                defer vk.cmdEndRendering(cb);
                const vp: vk.Viewport = .{
                    .width = @floatFromInt(windowsize.width),
                    .height = @floatFromInt(windowsize.height),
                    .maxDepth = 1.0,
                    .minDepth = 0.0,
                };
                vk.cmdSetViewport(cb, 0, 1, @ptrCast(&vp));
                const scissor: vk.Rect2D = .{ .extent = windowsize };
                vk.cmdSetScissor(cb, 0, 1, @ptrCast(&scissor));
                vk.cmdBindPipeline(cb, .graphics, pipeline);
                //textures
                vk.cmdBindDescriptorSets(cb, .graphics, pipeline_layout, 0, 1, @ptrCast(&desc_set), 0, undefined);

                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&suzanne_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, suzanne_buffer.handle, vBufferSize, .uint16);
                vk.cmdPushConstants(cb, pipeline_layout, .{ .vertex = true }, 0, @sizeOf(vk.DeviceAddress), std.mem.asBytes(&shader_buffers[frame_index].address(device)));
                vk.cmdDrawIndexed(cb, @intCast(suzanne.indices.items.len), 3, 0, 0, 0);

                vk.cmdBindVertexBuffers(cb, 0, 1, @ptrCast(&plane_buffer.handle), &.{0});
                vk.cmdBindIndexBuffer(cb, plane_buffer.handle, @sizeOf(f32) * plane_vertices.len, .uint16);
                vk.cmdDrawIndexed(cb, @intCast(quad_indices.len), 1, 0, 0, 0);
            }

            const present_barrier: vk.ImageMemoryBarrier2 = .{
                .srcStageMask = .{ .color_attachment_output = true },
                .srcAccessMask = .{ .color_attachment_write = true },
                .dstStageMask = .{ .color_attachment_output = true },
                .dstAccessMask = .{},
                .oldLayout = .attachment_optimal,
                .newLayout = .present_srcKHR,
                .image = images[image_index],
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
            };
            vk.cmdPipelineBarrier2(cb, &.{ .imageMemoryBarrierCount = 1, .pImageMemoryBarriers = @ptrCast(&present_barrier) });

            try vk.endCommandBuffer(cb);
        }

        const submit_info: vk.SubmitInfo = .{
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = @ptrCast(&presentSmp[frame_index]),
            .pWaitDstStageMask = &.{.{ .color_attachment_output = true }},
            .commandBufferCount = 1,
            .pCommandBuffers = @ptrCast(&cb),
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = @ptrCast(&renderSmp[image_index]),
        };
        try vk.queueSubmit(queue, 1, @ptrCast(&submit_info), fences[frame_index]);
        frame_index = (frame_index + 1) % max_frames;

        const present_info: vk.PresentInfoKHR = .{
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = @ptrCast(&renderSmp[image_index]),
            .swapchainCount = 1,
            .pSwapchains = @ptrCast(&swapchain),
            .pImageIndices = @ptrCast(&image_index),
        };

        vk.queuePresentKHR(queue, &present_info) catch |e| switch (e) {
            error.error_out_of_dateKHR, error.suboptimalKHR => recreate_swap = true,
            else => return e,
        };

        //input
        {
            const keyboard_state = sdl.getKeyboardState();
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
                        if (event.key.repeat) break;
                        switch (event.key.scancode) {
                            .h => sel = (sel + 1) % 3,
                            .escape => quit = true,
                            else => {},
                        }
                    },
                    .mouse_motion => {
                        cam.mouseInput(dT, event.motion.xrel, event.motion.yrel);
                    },
                    else => {},
                }
            }
        }

        if (recreate_swap) {
            recreate_swap = false;
            _ = sdl.getWindowSize(window, @ptrCast(&windowsize.width), @ptrCast(&windowsize.height));

            try vk.deviceWaitIdle(device);
            var surfaceCaps: vk.SurfaceCapabilitiesKHR = undefined;
            try vk.getPhysicalDeviceSurfaceCapabilitiesKHR(pdevice, surface, &surfaceCaps);
            swapchain_ci.oldSwapchain = swapchain;
            swapchain_ci.imageExtent = windowsize;
            try vk.createSwapchainKHR(device, &swapchain_ci, null, &swapchain);

            for (image_views) |view| {
                vk.destroyImageView(device, view, null);
            }

            try vk.getSwapchainImagesKHR(device, swapchain, &image_count, images.ptr);
            for (images, 0..) |img, i| {
                const ci: vk.ImageViewCreateInfo = .{
                    .image = img,
                    .viewType = .@"2d",
                    .format = image_format,
                    .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
                };
                try vk.createImageView(device, &ci, null, &image_views[i]);
            }
            for (renderSmp) |smp| {
                vk.destroySemaphore(device, smp, null);
            }
            for (renderSmp) |*smp| {
                try vk.createSemaphore(device, &.{}, null, smp);
            }
            vk.destroySwapchainKHR(device, swapchain_ci.oldSwapchain, null);
            vma.destroyImage(alloc, depth_image, depth_image_alloc);
            vk.destroyImageView(device, depth_image_view, null);

            depth_imageCI.extent = .{ .width = windowsize.width, .height = windowsize.height, .depth = 1 };
            const aci: vma.AllocationCreateInfo = .{ .usage = .auto, .flags = .{ .dedicated_memory_bit = true } };
            _ = vma.createImage(alloc, &depth_imageCI, &aci, &depth_image, &depth_image_alloc, null);
            const viewCI: vk.ImageViewCreateInfo = .{
                .image = depth_image,
                .viewType = .@"2d",
                .format = depth_format,
                .subresourceRange = .{ .aspectMask = .{ .depth = true }, .layerCount = 1, .levelCount = 1 },
            };
            try vk.createImageView(device, &viewCI, null, &depth_image_view);
        }
    }

    try vk.deviceWaitIdle(device);
}

const quad_indices: [6]u16 = .{
    0, 1, 2,
    2, 3, 0,
};

const plane_vertices: [32]f32 = .{
    -10.0, 1.0, 10.0,  0.0, 1.0, 0.0, 0.0, 1.0,
    10.0,  1.0, 10.0,  0.0, 1.0, 0.0, 1.0, 1.0,
    10.0,  1.0, -10.0, 0.0, 1.0, 0.0, 1.0, 0.0,
    -10.0, 1.0, -10.0, 0.0, 1.0, 0.0, 0.0, 0.0,
};
