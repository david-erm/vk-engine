const std = @import("std");
pub const c = @import("c");
const vk = @import("vk");
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

    //RH_ZO
    pub fn ortho(left: f32, right: f32, bottom: f32, top: f32) Mat4 {
        var result: Mat4 = .indentity;
        result.data[0][0] = 2 / (right - left);
        result.data[1][1] = 2 / (top - bottom);
        result.data[2][2] = -1;
        result.data[3][0] = -(right + left) / (right - left);
        result.data[3][1] = -(top + bottom) / (top - bottom);
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

    pub fn scale(v: Vec3, factor: f32) Vec3 {
        return .{ .x = v.x * factor, .y = v.y * factor, .z = v.z * factor };
    }

    pub fn norm(v: Vec3) f32 {
        return @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    }

    pub fn normalize(v: Vec3) Vec3 {
        const mag = v.norm();
        if (mag > 0) {
            return .{ .x = v.x / mag, .y = v.y / mag, .z = v.z / mag };
        } else return .{};
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

pub const Context = struct {
    instance: vk.Instance,
    pdevice: vk.PhysicalDevice,
    device: vk.Device,
    queue: vk.Queue,
    vka: vma.Allocator,
    qfamily: u32,

    pub fn deinit(ctx: *Context) void {
        defer sdl.deinit();
        defer vk.destroyInstance(ctx.instance, null);
        defer vk.destroyDevice(ctx.device, null);
        defer vma.destroyAllocator(ctx.vka);
    }

    pub fn init(arena: std.mem.Allocator) !Context {
        var ctx: Context = undefined;
        try sdl.init(.{ .video = true });
        try sdl.vulkan.loadLibrary(null);
        const instanceProcAddr = sdl.vulkan.getInstanceProcAddr();

        vk.load(instanceProcAddr);

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
            }, null, &ctx.instance);
            vk.loadInstance(ctx.instance);
        }

        {
            var device_count: u32 = 0;
            try vk.enumeratePhysicalDevices(ctx.instance, &device_count, null);
            const devices = try arena.alloc(vk.PhysicalDevice, device_count);
            try vk.enumeratePhysicalDevices(ctx.instance, &device_count, devices.ptr);
            const device_index: u32 = 0;
            ctx.pdevice = devices[device_index];
            for (devices) |d| {
                var dp: vk.PhysicalDeviceProperties2 = .{};
                vk.getPhysicalDeviceProperties2(d, &dp);
                log.info("dev: {s}", .{dp.properties.deviceName});
            }

            var device_properties: vk.PhysicalDeviceProperties2 = .{};
            vk.getPhysicalDeviceProperties2(devices[device_index], &device_properties);
            log.info("Selected device: {s}", .{device_properties.properties.deviceName});
        }

        {
            var queue_count: u32 = 0;
            ctx.qfamily = 0;
            vk.getPhysicalDeviceQueueFamilyProperties(ctx.pdevice, &queue_count, null);
            const queue_families = try arena.alloc(vk.QueueFamilyProperties, queue_count);
            vk.getPhysicalDeviceQueueFamilyProperties(ctx.pdevice, &queue_count, queue_families.ptr);
            while (!(queue_families[ctx.qfamily].queueFlags.graphics and queue_families[ctx.qfamily].queueFlags.compute)) : (ctx.qfamily += 1) {}
            try sdl.vulkan.getPresentationSupport(ctx.instance, ctx.pdevice, ctx.qfamily);
        }

        {
            const qfpriorities: [1]f32 = .{1.0};
            const queueCI: vk.DeviceQueueCreateInfo = .{
                .queueFamilyIndex = ctx.qfamily,
                .queueCount = 1,
                .pQueuePriorities = &qfpriorities,
            };
            var enableVK12Features: vk.PhysicalDeviceVulkan12Features = .{
                .descriptorIndexing = .True,
                .shaderSampledImageArrayNonUniformIndexing = .True,
                .runtimeDescriptorArray = .True,
                .bufferDeviceAddress = .True,
                .timelineSemaphore = .True,
                .descriptorBindingPartiallyBound = .True,
                //turned off, was used at some point
                .descriptorBindingUpdateUnusedWhilePending = .False,
                .descriptorBindingVariableDescriptorCount = .False,
            };
            const enableVK13Features: vk.PhysicalDeviceVulkan13Features = .{
                .pNext = &enableVK12Features,
                .synchronization2 = .True,
                .dynamicRendering = .True,
            };
            const enableVKFeatures: vk.PhysicalDeviceFeatures = .{
                .samplerAnisotropy = .True,
            };
            try vk.createDevice(ctx.pdevice, &.{
                .pNext = &enableVK13Features,
                .queueCreateInfoCount = 1,
                .pQueueCreateInfos = @ptrCast(&queueCI),
                .enabledExtensionCount = 1,
                .ppEnabledExtensionNames = &.{"VK_KHR_swapchain"},
                .pEnabledFeatures = &enableVKFeatures,
            }, null, &ctx.device);
            vk.loadDevice(ctx.device);
            vk.getDeviceQueue(ctx.device, ctx.qfamily, 0, &ctx.queue);
        }

        {
            const vkFuncs: vma.VulkanFunctions = .{
                .vkGetInstanceProcAddr = vk.table.instance.vkGetInstanceProcAddr,
                .vkGetDeviceProcAddr = vk.table.device.vkGetDeviceProcAddr,
                .vkCreateImage = vk.table.device.vkCreateImage,
            };
            _ = vma.createAllocator(&.{
                .flags = .{ .BufferDeviceAddressBit = 1 },
                .physicalDevice = ctx.pdevice,
                .device = ctx.device,
                .pVulkanFunctions = &vkFuncs,
                .instance = ctx.instance,
            }, &ctx.vka);
        }

        return ctx;
    }
};

pub const Image = struct {
    handle: vk.Image,
    view: vk.ImageView,
    allocation: vma.Allocation,
    format: vk.Format,
};

pub const RenderContext = struct {
    window: sdl.Window,
    windowsize: vk.Extent2D,
    surface: vk.SurfaceKHR,
    swapchain: vk.SwapchainKHR,
    swapchain_ci: vk.SwapchainCreateInfoKHR,
    sc_format: vk.Format,
    sc_imgs: []vk.Image,
    sc_img_views: []vk.ImageView,
    sc_view_dsc: []vk.DescriptorImageInfo,
    depth: Image,
    depth_ci: vk.ImageCreateInfo,
    loop_tml: vk.Semaphore,
    fif_semaphore: []vk.Semaphore,
    swapchain_semaphore: []vk.Semaphore,

    pub fn deinit(rctx: *RenderContext, ctx: Context) void {
        defer sdl.destroyWindow(&rctx.window);
        defer vk.destroySurfaceKHR(ctx.instance, rctx.surface, null);
        defer vk.destroySwapchainKHR(ctx.device, rctx.swapchain, null);
        defer for (rctx.sc_img_views) |view| {
            vk.destroyImageView(ctx.device, view, null);
        };
        defer for (rctx.fif_semaphore) |smp| {
            vk.destroySemaphore(ctx.device, smp, null);
        };
        vk.destroySemaphore(ctx.device, rctx.loop_tml, null);
        defer for (rctx.swapchain_semaphore) |semaphore| {
            vk.destroySemaphore(ctx.device, semaphore, null);
        };
        defer vma.destroyImage(ctx.vka, rctx.depth.handle, rctx.depth.allocation);
        defer vk.destroyImageView(ctx.device, rctx.depth.view, null);
    }

    pub fn init(ctx: *const Context, arena: std.mem.Allocator, width: u32, height: u32, name: [:0]const u8, frames_in_flight: usize) !RenderContext {
        var rctx: RenderContext = undefined;
        rctx.windowsize.width = width;
        rctx.windowsize.height = height;

        rctx.window = try sdl.createWindow(name.ptr, @intCast(rctx.windowsize.width), @intCast(rctx.windowsize.height), .{
            .vulkan = true,
            .resizable = true,
            .fullscreen = true,
            .borderless = true,
        });
        rctx.surface = try sdl.vulkan.createSurface(rctx.window, ctx.instance, null);

        rctx.sc_format = try fmt: {
            var format_count: u32 = 0;
            try vk.getPhysicalDeviceSurfaceFormatsKHR(ctx.pdevice, rctx.surface, &format_count, null);
            const formats = try arena.alloc(vk.SurfaceFormatKHR, format_count);
            defer arena.free(formats);
            try vk.getPhysicalDeviceSurfaceFormatsKHR(ctx.pdevice, rctx.surface, &format_count, formats.ptr);
            for (formats) |format| {
                var props: vk.FormatProperties2 = .{};
                vk.getPhysicalDeviceFormatProperties2(ctx.pdevice, format.format, &props);
                log.info("format: {}", .{format.format});
                if (props.formatProperties.optimalTilingFeatures.storage_image) {
                    break :fmt format.format;
                }
            }
            break :fmt error.FormatNotFound;
        };
        rctx.sc_format = .b8g8r8a8_unorm;

        {
            var surfaceCaps: vk.SurfaceCapabilitiesKHR = undefined;
            try vk.getPhysicalDeviceSurfaceCapabilitiesKHR(ctx.pdevice, rctx.surface, &surfaceCaps);
            std.debug.assert(surfaceCaps.supportedUsageFlags.storage);
            rctx.swapchain_ci = .{
                .surface = rctx.surface,
                .minImageCount = surfaceCaps.minImageCount,
                .imageFormat = rctx.sc_format,
                .imageColorSpace = .srgb_nonlinear,
                .imageExtent = rctx.windowsize,
                .imageArrayLayers = 1,
                .imageUsage = .{ .color_attachment = true, .storage = true },
                .preTransform = .{ .identity = true },
                .compositeAlpha = .{ .@"opaque" = true },
                .presentMode = .fifo,
            };
            try vk.createSwapchainKHR(ctx.device, &rctx.swapchain_ci, null, &rctx.swapchain);
        }

        {
            var image_count: u32 = 0;
            try vk.getSwapchainImagesKHR(ctx.device, rctx.swapchain, &image_count, null);
            rctx.sc_imgs = try arena.alloc(vk.Image, image_count);
            try vk.getSwapchainImagesKHR(ctx.device, rctx.swapchain, &image_count, rctx.sc_imgs.ptr);

            rctx.sc_img_views = try arena.alloc(vk.ImageView, rctx.sc_imgs.len);
            for (0..rctx.sc_imgs.len) |i| {
                const image_viewCI: vk.ImageViewCreateInfo = .{
                    .image = rctx.sc_imgs[i],
                    .viewType = .@"2d",
                    .format = rctx.sc_format,
                    .subresourceRange = .{
                        .aspectMask = .{ .color = true },
                        .layerCount = 1,
                        .levelCount = 1,
                    },
                };
                try vk.createImageView(ctx.device, &image_viewCI, null, &rctx.sc_img_views[i]);
            }
            rctx.sc_view_dsc = try arena.alloc(vk.DescriptorImageInfo, rctx.sc_img_views.len);
            for (rctx.sc_view_dsc, 0..) |*desc, i| {
                desc.imageView = rctx.sc_img_views[i];
                desc.imageLayout = .general;
            }
        }

        rctx.fif_semaphore = try arena.alloc(vk.Semaphore, frames_in_flight);
        rctx.swapchain_semaphore = try arena.alloc(vk.Semaphore, rctx.sc_imgs.len);
        {
            const semaphoreCI: vk.SemaphoreCreateInfo = .{};
            for (rctx.fif_semaphore) |*semaphore| {
                try vk.createSemaphore(ctx.device, &.{}, null, semaphore);
            }
            for (rctx.swapchain_semaphore) |*semaphore| {
                try vk.createSemaphore(ctx.device, &semaphoreCI, null, semaphore);
            }
            const tml: vk.SemaphoreTypeCreateInfo = .{ .semaphoreType = .timeline };
            const tml_ci: vk.SemaphoreCreateInfo = .{ .pNext = &tml };
            try vk.createSemaphore(ctx.device, &tml_ci, null, &rctx.loop_tml);
        }

        const depth_formats: [2]vk.Format = .{ .d32_sfloat_s8_uint, .d24_unorm_s8_uint };
        for (depth_formats) |format| {
            var formatProperties: vk.FormatProperties2 = .{ .formatProperties = .{} };
            vk.getPhysicalDeviceFormatProperties2(ctx.pdevice, format, &formatProperties);
            if (formatProperties.formatProperties.optimalTilingFeatures.depth_stencil_attachment) {
                rctx.depth.format = format;
                break;
            }
        }
        std.debug.assert(rctx.depth.format != vk.Format.undefined);

        rctx.depth_ci = .{
            .extent = .{ .width = rctx.windowsize.width, .height = rctx.windowsize.height, .depth = 1 },
            .arrayLayers = 1,
            .mipLevels = 1,
            .format = rctx.depth.format,
            .imageType = .@"2d",
            .initialLayout = .undefined,
            .tiling = .optimal,
            .usage = .{ .depth_stencil_attachment = true },
            .samples = .{ .@"1" = true },
        };

        const alloc_ci: vma.AllocationCreateInfo = .{ .usage = .auto };
        _ = vma.createImage(ctx.vka, &rctx.depth_ci, &alloc_ci, &rctx.depth.handle, &rctx.depth.allocation, null);

        const depthImageViewCI: vk.ImageViewCreateInfo = .{
            .format = rctx.depth.format,
            .viewType = .@"2d",
            .image = rctx.depth.handle,
            .subresourceRange = .{
                .aspectMask = .{ .depth = true },
                .layerCount = 1,
                .levelCount = 1,
            },
        };
        try vk.createImageView(ctx.device, &depthImageViewCI, null, &rctx.depth.view);

        return rctx;
    }

    pub fn recreate_swap(rctx: *RenderContext, ctx: *const Context) !void {
        _ = sdl.getWindowSize(rctx.window, @ptrCast(&rctx.windowsize.width), @ptrCast(&rctx.windowsize.height));

        try vk.queueWaitIdle(ctx.queue);

        var surfaceCaps: vk.SurfaceCapabilitiesKHR = undefined;
        try vk.getPhysicalDeviceSurfaceCapabilitiesKHR(ctx.pdevice, rctx.surface, &surfaceCaps);
        rctx.swapchain_ci.oldSwapchain = rctx.swapchain;
        rctx.swapchain_ci.imageExtent = rctx.windowsize;
        try vk.createSwapchainKHR(ctx.device, &rctx.swapchain_ci, null, &rctx.swapchain);

        for (rctx.sc_img_views) |view| {
            vk.destroyImageView(ctx.device, view, null);
        }

        var count: u32 = @intCast(rctx.sc_imgs.len);
        try vk.getSwapchainImagesKHR(ctx.device, rctx.swapchain, &count, rctx.sc_imgs.ptr);
        for (rctx.sc_imgs, 0..) |img, i| {
            const ci: vk.ImageViewCreateInfo = .{
                .image = img,
                .viewType = .@"2d",
                .format = rctx.sc_format,
                .subresourceRange = .{ .aspectMask = .{ .color = true }, .layerCount = 1, .levelCount = 1 },
            };
            try vk.createImageView(ctx.device, &ci, null, &rctx.sc_img_views[i]);
            rctx.sc_view_dsc[i].imageView = rctx.sc_img_views[i];
            rctx.sc_view_dsc[i].imageLayout = .general;
        }

        for (rctx.swapchain_semaphore) |smp| {
            vk.destroySemaphore(ctx.device, smp, null);
        }
        for (rctx.swapchain_semaphore) |*smp| {
            try vk.createSemaphore(ctx.device, &.{}, null, smp);
        }

        vk.destroySwapchainKHR(ctx.device, rctx.swapchain_ci.oldSwapchain, null);
        vma.destroyImage(ctx.vka, rctx.depth.handle, rctx.depth.allocation);
        vk.destroyImageView(ctx.device, rctx.depth.view, null);

        rctx.depth_ci.extent = .{ .width = rctx.windowsize.width, .height = rctx.windowsize.height, .depth = 1 };
        const aci: vma.AllocationCreateInfo = .{ .usage = .auto, .flags = .{ .dedicated_memory_bit = true } };
        _ = vma.createImage(ctx.vka, &rctx.depth_ci, &aci, &rctx.depth.handle, &rctx.depth.allocation, null);
        const viewCI: vk.ImageViewCreateInfo = .{
            .image = rctx.depth.handle,
            .viewType = .@"2d",
            .format = rctx.depth.format,
            .subresourceRange = .{ .aspectMask = .{ .depth = true }, .layerCount = 1, .levelCount = 1 },
        };
        try vk.createImageView(ctx.device, &viewCI, null, &rctx.depth.view);
    }
};

pub const Buffer = struct {
    handle: vk.Buffer,
    alloc: vma.Allocation,
    alloci: vma.AllocationInfo,

    pub fn deinit(buff: Buffer, vka: vma.Allocator) void {
        vma.destroyBuffer(vka, buff.handle, buff.alloc);
    }

    pub fn init(vka: vma.Allocator, ci: vk.BufferCreateInfo, ai: vma.AllocationCreateInfo) Buffer {
        var ret: Buffer = undefined;
        _ = vma.createBuffer(vka, &ci, &ai, &ret.handle, &ret.alloc, &ret.alloci);
        return ret;
    }

    pub fn write(buff: Buffer, offset: u64, data: anytype) void {
        switch (@typeInfo(@TypeOf(data))) {
            .pointer => {
                @memcpy(@as([*]u8, @ptrCast(@alignCast(buff.alloci.pMappedData.?))) + offset, std.mem.sliceAsBytes(data));
            },
            .@"struct", .array => {
                @memcpy(@as([*]u8, @ptrCast(@alignCast(buff.alloci.pMappedData.?))) + offset, std.mem.asBytes(&data));
            },
            else => @compileError("needs to be either struct or slice"),
        }
    }

    pub fn address(buff: Buffer, device: vk.Device) vk.DeviceAddress {
        return vk.getBufferDeviceAddress(device, &.{ .buffer = buff.handle });
    }
};

pub const Pose = extern struct {
    pos: Vec3 = .{},
    extra: f32 = 1,
    rot: Quat = .identity,
};

pub const Camera = struct {
    const pitch_limit = std.math.pi / 2.0 - 0.1;

    pose: Pose = .{ .extra = 0 },
    sens: f32 = 0.002,
    movespeed: f32 = 10,
    fov: f32 = std.math.pi / 3.0,

    pub fn mouseInput(cam: *Camera, relative_x: f32, relative_y: f32) void {
        const old_pitch = cam.pose.extra;
        const f = cam.sens;

        cam.pose.extra += relative_y * f;
        if (@abs(cam.pose.extra) > pitch_limit) {
            const diff = @as(f32, std.math.sign(old_pitch)) * pitch_limit - old_pitch;
            cam.pose.rot = cam.pose.rot.mul(.fromAngleAxis(diff, .{ .x = 1 }));
            cam.pose.extra = old_pitch + diff;
        } else cam.pose.rot = cam.pose.rot.mul(.fromAngleAxis(relative_y * f, .{ .x = 1 }));

        cam.pose.rot = Quat.mul(.fromAngleAxis(-relative_x * f, .{ .y = 1 }), cam.pose.rot);
        cam.pose.rot = cam.pose.rot.normalize();
    }

    pub fn moveInput(cam: *Camera, dT: f32, in: [4]bool) void {
        var axis: Vec3 = .{};
        const lookup: [4]Vec3 = .{
            Vec3{ .z = -1 },
            Vec3{ .z = 1 },
            Vec3{ .x = 1 },
            Vec3{ .x = -1 },
        };

        for (lookup, in) |v, dir| {
            if (dir) {
                axis = axis.add(v);
            }
        }

        axis = axis.normalize();

        cam.pose.pos = Vec3.add(cam.pose.pos, .rotate(axis.scale(dT * cam.movespeed), cam.pose.rot));
    }
};

pub const ShaderDataBuffer = struct {
    allocInfo: vma.AllocationInfo,
    alloc: vma.Allocation,
    buffer: vk.Buffer,
    address: vk.DeviceAddress,
};

pub const LoadedMesh = struct {
    indices: std.ArrayList(u32),
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

    const alloc_ci: vma.AllocationCreateInfo = .{ .usage = .auto };
    _ = vma.createImage(vka, &image_ci, &alloc_ci, &info.image, &info.alon, null);
    errdefer vma.destroyImage(vka, info.image, info.alon);

    const img_buffer = Buffer.init(
        vka,
        .{ .size = texture.dataSize, .usage = .{ .transfer_src = true } },
        .{ .usage = .auto, .flags = .{
            .mapped_bit = true,
            .host_access_sequential_write_bit = true,
        } },
    );
    defer img_buffer.deinit(vka);
    img_buffer.write(0, texture.pData[0..texture.dataSize]);

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
            .levelCount = image_ci.mipLevels,
            .layerCount = image_ci.arrayLayers,
        },
    };
    var barrier_texinfo: vk.DependencyInfo = .{
        .imageMemoryBarrierCount = 1,
        .pImageMemoryBarriers = @ptrCast(&mem_barrier),
    };
    vk.cmdPipelineBarrier2(cmd_buf, &barrier_texinfo);

    const copy_regions = try a.alloc(vk.BufferImageCopy, image_ci.mipLevels * image_ci.arrayLayers);
    defer a.free(copy_regions);
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
    vk.cmdCopyBufferToImage(cmd_buf, img_buffer.handle, info.image, .transfer_dst_optimal, @intCast(copy_regions.len), copy_regions.ptr);

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
            .levelCount = image_ci.mipLevels,
            .layerCount = image_ci.arrayLayers,
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

    const sampler_ci: vk.SamplerCreateInfo = .{
        .magFilter = .linear,
        .minFilter = .linear,
        .mipmapMode = .linear,
        .anisotropyEnable = .True,
        .maxAnisotropy = 8.0,
        .borderColor = .float_transparent_black,
        .maxLod = @floatFromInt(image_ci.mipLevels),
    };
    try vk.createSampler(device, &sampler_ci, null, &info.sampler);

    var view_ci: vk.ImageViewCreateInfo = .{
        .format = format,
        .image = info.image,
        .subresourceRange = .{
            .layerCount = image_ci.arrayLayers,
            .levelCount = image_ci.mipLevels,
            .aspectMask = .{ .color = true },
        },
    };
    if (texture.isCubemap) {
        view_ci.viewType = .cube;
    } else view_ci.viewType = .@"2d";
    try vk.createImageView(device, &view_ci, null, &info.view);

    try vk.waitForFences(device, 1, @ptrCast(&fence), .True, std.math.maxInt(u64));
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
    var indices: std.ArrayList(u32) = .empty;
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
