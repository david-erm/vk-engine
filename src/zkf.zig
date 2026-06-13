const std = @import("std");
const Io = std.Io;

pub const c = @import("c");
const vk = @import("vk");
const gltf = @import("zgltf").Gltf;
const sdl = @import("sdl.zig");
const vma = @import("vma.zig");
const ktx = @import("ktx.zig");
const vk_extensions = @import("vk_extensions");

pub const AssetManager = @import("AssetManager.zig");

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

pub fn Vec(T: type, len: u32) type {
    const field_names: []const []const u8 = &.{ "x", "y", "z", "w" };
    return @Struct(.@"extern", null, field_names[0..len], &@splat(T), &@splat(.{}));
}

test {
    const v1: Vec(f32, 3) = .{ .x = 1.0, .y = 2.0, .z = 2.0 };
    const v2: Vec(f32, 3) = .{ .x = -1.0, .y = -2.0, .z = -2.0 };
    const v3 = v1.add(v2);
    std.debug.print("{}", .{v3});
}

pub const Vec2 = extern struct { x: f32 = 0, y: f32 = 0 };
pub const IVec2 = extern struct { x: i32 = 0, y: i32 = 0 };
pub const UVec2 = extern struct { x: u32 = 0, y: u32 = 0 };
// pub const Vertex = extern struct { pos: Vec3, norm: Vec3, uv: Vec2 };
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

    pub fn mul(v1: Vec3, v2: Vec3) Vec3 {
        return .{ .x = v1.x * v2.x, .y = v1.y * v2.y, .z = v1.z * v2.z };
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
    _ = v2;
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
            const platform_extensions = try sdl.vulkan.getInstanceExtensions();
            var extensions: std.ArrayList([*:0]const u8) = .empty;

            try extensions.appendSlice(arena, platform_extensions);
            for (vk_extensions.instance_extensions) |ext| {
                try extensions.append(arena, ext.ptr);
            }

            const app_info: vk.ApplicationInfo = .{
                .apiVersion = vk.makeApiVersion(0, 1, 3, 0),
                .pApplicationName = "howtovulkna",
                .applicationVersion = vk.makeApiVersion(0, 1, 0, 0),
                .pEngineName = "zkf",
                .engineVersion = vk.makeApiVersion(0, 1, 0, 0),
            };
            try vk.createInstance(&.{
                .pApplicationInfo = &app_info,
                .enabledExtensionCount = @intCast(extensions.items.len),
                .ppEnabledExtensionNames = extensions.items.ptr,
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
                var features: vk.PhysicalDeviceFeatures2 = .{};
                vk.getPhysicalDeviceFeatures2(d, &features);
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
            };
            const enableVK13Features: vk.PhysicalDeviceVulkan13Features = .{
                .pNext = &enableVK12Features,
                .synchronization2 = .True,
                .dynamicRendering = .True,
            };
            const enableVKFeatures: vk.PhysicalDeviceFeatures = .{
                .samplerAnisotropy = .True,
            };
            var extensions: std.ArrayList([*:0]const u8) = .empty;
            for (vk_extensions.device_extensions) |ext| {
                try extensions.append(arena, ext.ptr);
            }
            try vk.createDevice(ctx.pdevice, &.{
                .pNext = &enableVK13Features,
                .queueCreateInfoCount = 1,
                .pQueueCreateInfos = @ptrCast(&queueCI),
                .enabledExtensionCount = 1,
                .ppEnabledExtensionNames = extensions.items.ptr,
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
            try vma.createAllocator(&.{
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

pub const RenderContext = struct {
    window: sdl.Window,
    windowsize: vk.Extent2D,
    surface: vk.SurfaceKHR,
    swapchain: vk.SwapchainKHR,
    swapchain_ci: vk.SwapchainCreateInfoKHR,
    sc_format: vk.Format,
    sc_imgs: []vk.Image,
    sc_img_views: []AssetManager.ViewHandle,
    depth: AssetManager.ImageHandle,
    depth_view: AssetManager.ViewHandle,
    depth_format: vk.Format,
    depth_ci: vk.ImageCreateInfo,
    loop_tml: vk.Semaphore,
    fif_semaphore: []vk.Semaphore,
    swapchain_semaphore: []vk.Semaphore,

    pub fn deinit(rctx: *RenderContext, ctx: *const Context, manager: *AssetManager) void {
        defer sdl.destroyWindow(&rctx.window);
        defer vk.destroySurfaceKHR(ctx.instance, rctx.surface, null);
        defer vk.destroySwapchainKHR(ctx.device, rctx.swapchain, null);
        defer for (rctx.sc_img_views) |view| {
            manager.freeStorageImage(ctx, view);
        };
        defer for (rctx.fif_semaphore) |smp| {
            vk.destroySemaphore(ctx.device, smp, null);
        };
        vk.destroySemaphore(ctx.device, rctx.loop_tml, null);
        defer for (rctx.swapchain_semaphore) |semaphore| {
            vk.destroySemaphore(ctx.device, semaphore, null);
        };
        defer manager.freeImage(ctx, rctx.depth);
        defer manager.freeSampledImage(ctx, rctx.depth_view);
    }

    pub fn init(
        ctx: *const Context,
        static: std.mem.Allocator,
        // startup: std.mem.Allocator,
        width: u32,
        height: u32,
        name: [:0]const u8,
        frames_in_flight: usize,
        manager: *AssetManager,
    ) !RenderContext {
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

        // rctx.sc_format = try fmt: {
        //     var format_count: u32 = 0;
        //     try vk.getPhysicalDeviceSurfaceFormatsKHR(ctx.pdevice, rctx.surface, &format_count, null);
        //     const formats = try startup.alloc(vk.SurfaceFormatKHR, format_count);
        //     try vk.getPhysicalDeviceSurfaceFormatsKHR(ctx.pdevice, rctx.surface, &format_count, formats.ptr);
        //     for (formats) |format| {
        //         var props: vk.FormatProperties2 = .{};
        //         vk.getPhysicalDeviceFormatProperties2(ctx.pdevice, format.format, &props);
        //         if (props.formatProperties.optimalTilingFeatures.storage_image) {
        //             break :fmt format.format;
        //         }
        //     }
        //     break :fmt error.FormatNotFound;
        // };
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
            rctx.sc_imgs = try static.alloc(vk.Image, image_count);
            try vk.getSwapchainImagesKHR(ctx.device, rctx.swapchain, &image_count, rctx.sc_imgs.ptr);

            rctx.sc_img_views = try static.alloc(AssetManager.ViewHandle, rctx.sc_imgs.len);
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
                rctx.sc_img_views[i] = try manager.allocStorageImage(ctx, image_viewCI);
            }
        }

        rctx.fif_semaphore = try static.alloc(vk.Semaphore, frames_in_flight);
        rctx.swapchain_semaphore = try static.alloc(vk.Semaphore, rctx.sc_imgs.len);
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
        rctx.depth_format = for (depth_formats) |format| {
            var formatProperties: vk.FormatProperties2 = .{ .formatProperties = .{} };
            vk.getPhysicalDeviceFormatProperties2(ctx.pdevice, format, &formatProperties);
            if (formatProperties.formatProperties.optimalTilingFeatures.depth_stencil_attachment) {
                break format;
            }
        } else return error.DepthFormatNotFound;

        rctx.depth_ci = .{
            .extent = .{ .width = rctx.windowsize.width, .height = rctx.windowsize.height, .depth = 1 },
            .arrayLayers = 1,
            .mipLevels = 1,
            .format = rctx.depth_format,
            .imageType = .@"2d",
            .initialLayout = .undefined,
            .tiling = .optimal,
            .usage = .{ .depth_stencil_attachment = true, .sampled = true },
            .samples = .{ .@"1" = true },
        };
        rctx.depth = try manager.allocImage(ctx, rctx.depth_ci);

        const depthImageViewCI: vk.ImageViewCreateInfo = .{
            .format = rctx.depth_format,
            .viewType = .@"2d",
            .image = manager.getImage(rctx.depth),
            .subresourceRange = .{
                .aspectMask = .{ .depth = true },
                .layerCount = 1,
                .levelCount = 1,
            },
        };
        rctx.depth_view = try manager.allocSampledImage(ctx, depthImageViewCI);

        return rctx;
    }

    pub fn recreate_swap(rctx: *RenderContext, ctx: *const Context, manager: *AssetManager) !void {
        _ = sdl.getWindowSize(rctx.window, @ptrCast(&rctx.windowsize.width), @ptrCast(&rctx.windowsize.height));

        try vk.queueWaitIdle(ctx.queue);

        // not used, dont need to track this
        var surfaceCaps: vk.SurfaceCapabilitiesKHR = undefined;
        try vk.getPhysicalDeviceSurfaceCapabilitiesKHR(ctx.pdevice, rctx.surface, &surfaceCaps);

        rctx.swapchain_ci.oldSwapchain = rctx.swapchain;
        rctx.swapchain_ci.imageExtent = rctx.windowsize;
        try vk.createSwapchainKHR(ctx.device, &rctx.swapchain_ci, null, &rctx.swapchain);

        for (rctx.sc_img_views) |view| {
            manager.freeStorageImage(ctx, view);
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
            rctx.sc_img_views[i] = try manager.allocStorageImage(ctx, ci);
        }

        for (rctx.swapchain_semaphore) |smp| {
            vk.destroySemaphore(ctx.device, smp, null);
        }
        for (rctx.swapchain_semaphore) |*smp| {
            try vk.createSemaphore(ctx.device, &.{}, null, smp);
        }

        vk.destroySwapchainKHR(ctx.device, rctx.swapchain_ci.oldSwapchain, null);
        manager.freeImage(ctx, rctx.depth);
        manager.freeSampledImage(ctx, rctx.depth_view);

        rctx.depth_ci.extent = .{ .width = rctx.windowsize.width, .height = rctx.windowsize.height, .depth = 1 };
        rctx.depth = try manager.allocImage(ctx, rctx.depth_ci);
        const viewCI: vk.ImageViewCreateInfo = .{
            .image = manager.getImage(rctx.depth),
            .viewType = .@"2d",
            .format = rctx.depth_format,
            .subresourceRange = .{ .aspectMask = .{ .depth = true }, .layerCount = 1, .levelCount = 1 },
        };
        rctx.depth_view = try manager.allocSampledImage(ctx, viewCI);
    }
};

pub fn ObjectPool(T: type) type {
    return struct {
        const Error = error{OutOfMemory};
        const list_end = std.math.maxInt(u32);
        pub const Element = union {
            next: u32,
            val: T,
        };
        head: u32,
        pool: []Element,

        pub fn init(gpa: std.mem.Allocator, size: usize) !@This() {
            const pool: []Element = try gpa.alloc(Element, size);

            for (pool[0 .. size - 1], 0..) |*elem, i| {
                elem.* = .{ .next = @intCast(i + 1) };
            }

            pool[size - 1] = .{ .next = list_end };

            return .{
                .head = 0,
                .pool = pool,
            };
        }

        pub fn push(pool: *@This(), val: T) Error!u32 {
            if (pool.head != list_end) {
                const idx = pool.head;
                pool.head = pool.pool[idx].next;
                pool.pool[idx] = .{ .val = val };
                return idx;
            } else {
                return Error.OutOfMemory;
            }
        }

        pub fn get(pool: *@This(), idx: u32) T {
            return pool.pool[idx].val;
        }

        pub fn getPtr(pool: *@This(), idx: u32) *T {
            return &pool.pool[idx].val;
        }

        pub fn pop(pool: *@This(), idx: u32) void {
            pool.pool[idx] = .{ .next = pool.head };
            pool.head = idx;
        }

        pub fn deinit(object_pool: *@This(), gpa: std.mem.Allocator) void {
            gpa.free(object_pool.pool);
        }
    };
}

pub const Buffer = struct {
    handle: vk.Buffer,
    alloc: vma.Allocation,
    alloci: vma.AllocationInfo,

    pub fn deinit(buff: Buffer, vka: vma.Allocator) void {
        vma.destroyBuffer(vka, buff.handle, buff.alloc);
    }

    pub fn init(vka: vma.Allocator, ci: vk.BufferCreateInfo, ai: vma.AllocationCreateInfo) !Buffer {
        var ret: Buffer = undefined;
        try vma.createBuffer(vka, &ci, &ai, &ret.handle, &ret.alloc, &ret.alloci);
        return ret;
    }

    pub fn write(buff: Buffer, offset: u64, data: anytype) void {
        switch (@typeInfo(@TypeOf(data))) {
            .pointer => {
                @memcpy(@as([*]u8, @ptrCast(@alignCast(buff.alloci.pMappedData.?))) + offset, std.mem.sliceAsBytes(data));
            },
            else => {
                @memcpy(@as([*]u8, @ptrCast(@alignCast(buff.alloci.pMappedData.?))) + offset, std.mem.asBytes(&data));
            },
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

pub const FileDataCtx = struct {
    io: *std.Io,
    arena: std.mem.Allocator,
    mmaps: std.ArrayList(std.Io.File.MemoryMap),
    count: usize = 0,
};

pub fn get_file_data(ioparam: ?*anyopaque, filename: [*c]const u8, _: i32, _: ?[*]const u8, buf: ?*?[*]u8, len: ?*usize) callconv(.c) void {
    if (filename == null) {
        log.err("bad filename", .{});
        buf.?.* = null;
        len.?.* = 0;
        return;
    }
    var ctx: *FileDataCtx = @ptrCast(@alignCast(ioparam));
    const io = ctx.io.*;
    ctx.count += 1;

    const cwd = std.Io.Dir.cwd();
    const sfilename = std.mem.span(filename);
    log.debug("attempting to open: {s}", .{sfilename});

    const file = cwd.openFile(io, sfilename, .{ .mode = .read_only }) catch @panic("failed to open file");
    defer file.close(io);

    const stat = file.stat(io) catch @panic("failed to stat file");
    const mmap = file.createMemoryMap(io, .{ .len = stat.size, .protection = .{ .read = true } }) catch @panic("failed to mmap file");
    ctx.mmaps.append(ctx.arena, mmap) catch @panic("fuck");

    buf.?.* = mmap.memory.ptr;
    len.?.* = mmap.memory.len;
}
