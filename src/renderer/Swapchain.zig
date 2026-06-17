const std = @import("std");
const log = std.log.scoped(.renderer);

const vk = @import("vk");

const Context = @import("Renderer.zig").Context;

const Swapchain = @This();

handle: vk.SwapchainKHR,
extent: vk.Extent2D,
surface: vk.SurfaceKHR,
format: vk.SurfaceFormatKHR,
images: []vk.Image,
semaphores: []vk.Semaphore,
index: u32,
should_recreate: bool,

//TODO: can maybe make this a paramter?
//will likely hardcode blit only for now
const usage: vk.ImageUsageFlags = .{
    .transfer_dst = true,
};

pub fn deinit(swapchain: *Swapchain, ctx: *const Context, gpa: std.mem.Allocator) void {
    for (swapchain.semaphores) |smp| {
        vk.destroySemaphore(ctx.device, smp, null);
    }
    gpa.free(swapchain.images.ptr[0 .. swapchain.images.len * 2]);
    vk.destroySwapchainKHR(ctx.device, swapchain.handle, null);
    vk.destroySurfaceKHR(ctx.instance, swapchain.surface, null);
}

pub fn init(ctx: *const Context, gpa: std.mem.Allocator, surface: vk.SurfaceKHR, extent: vk.Extent2D) !Swapchain {
    var swapchain: Swapchain = undefined;
    swapchain.surface = surface;
    swapchain.extent = extent;

    //TODO: not hardcode last param
    swapchain.format = try selectSwapchainFormat(ctx.pdevice, swapchain.surface, &.{ .b8g8r8a8_srgb, .r8g8b8a8_srgb }, .{ .blit_dst = true });
    log.debug("picked {t} format for swapchain", .{swapchain.format.format});

    var surface_caps: vk.SurfaceCapabilitiesKHR = undefined;
    try vk.getPhysicalDeviceSurfaceCapabilitiesKHR(ctx.pdevice, swapchain.surface, &surface_caps);
    const supported: u32 = @bitCast(surface_caps.supportedUsageFlags);
    const usage_bits: u32 = @bitCast(usage);
    if (supported & usage_bits != usage_bits) return error.NoSurfaceMatch;

    const ci: vk.SwapchainCreateInfoKHR = .{
        .surface = swapchain.surface,
        .minImageCount = surface_caps.minImageCount,
        .imageFormat = swapchain.format.format,
        .imageColorSpace = swapchain.format.colorSpace,
        .imageExtent = swapchain.extent,
        .imageUsage = usage,
        .imageArrayLayers = 1,
        .preTransform = .{ .identity = true },
        .compositeAlpha = .{ .@"opaque" = true },
        .presentMode = .fifo,
    };
    try vk.createSwapchainKHR(ctx.device, &ci, null, &swapchain.handle);

    var image_count: u32 = 0;
    try vk.getSwapchainImagesKHR(ctx.device, swapchain.handle, &image_count, null);
    const buffer = try gpa.alloc(*anyopaque, image_count * 2);
    swapchain.images = @ptrCast(buffer[0..image_count]);
    try vk.getSwapchainImagesKHR(ctx.device, swapchain.handle, &image_count, swapchain.images.ptr);

    swapchain.semaphores = @ptrCast(buffer[image_count .. image_count + image_count]);
    const smp_ci: vk.SemaphoreCreateInfo = .{};
    for (swapchain.semaphores) |*smp| {
        try vk.createSemaphore(ctx.device, &smp_ci, null, smp);
    }

    return swapchain;
}

pub fn recreate(swapchain: *Swapchain, ctx: *const Context, extent: vk.Extent2D) !void {
    swapchain.extent = extent;

    swapchain.format = try selectSwapchainFormat(ctx.pdevice, swapchain.surface, &.{ .b8g8r8a8_srgb, .r8g8b8_srgb }, .{ .blit_dst = true });
    log.debug("picked {t} format for swapchain", .{swapchain.format.format});

    var surface_caps: vk.SurfaceCapabilitiesKHR = undefined;
    try vk.getPhysicalDeviceSurfaceCapabilitiesKHR(ctx.pdevice, swapchain.surface, &surface_caps);
    const supported: u32 = @bitCast(surface_caps.supportedUsageFlags);
    const usage_bits: u32 = @bitCast(usage);
    if (supported & usage_bits != usage_bits) return error.NoSurfaceMatch;

    const ci: vk.SwapchainCreateInfoKHR = .{
        .surface = swapchain.surface,
        .minImageCount = surface_caps.minImageCount,
        .imageFormat = swapchain.format.format,
        .imageColorSpace = swapchain.format.colorSpace,
        .imageExtent = swapchain.extent,
        .imageUsage = usage,
        .imageArrayLayers = 1,
        .preTransform = .{ .identity = true },
        .compositeAlpha = .{ .@"opaque" = true },
        .presentMode = .fifo,
        .oldSwapchain = swapchain.handle,
    };
    try vk.createSwapchainKHR(ctx.device, &ci, null, &swapchain.handle);
    var count: u32 = undefined;
    try vk.getSwapchainImagesKHR(ctx.device, swapchain.handle, &count, null);
    std.debug.assert(count == swapchain.images.len);
    try vk.getSwapchainImagesKHR(ctx.device, swapchain.handle, &count, swapchain.images.ptr);

    //do i even need to?
    // for (swapchain.semaphores) |smp| {
    //     vk.destroySemaphore(ctx.device ,);
    // }

    vk.destroySwapchainKHR(ctx.device, ci.oldSwapchain, null);
}

//TODO: both acquire and present are likely bette fitted as an operation by Renderer.zig that takes in a swapchain/window as param
///`signal` is signaled when the swapchain image is ready for use
pub fn acquire(swapchain: *Swapchain, ctx: *const Context, signal: vk.Semaphore) error{AcquireFailed}!vk.Image {
    vk.acquireNextImageKHR(ctx.device, swapchain.handle, std.math.maxInt(u64), signal, null, &swapchain.index) catch |e| switch (e) {
        error.error_out_of_dateKHR, error.suboptimalKHR => swapchain.should_recreate = true,
        //TODO: https://docs.vulkan.org/spec/latest/chapters/VK_KHR_surface/wsi.html#vkAcquireNextImageKHR
        else => return error.AcquireFailed,
    };
    return swapchain.images[swapchain.index];
}

pub fn present(swapchain: *Swapchain, ctx: *const Context) !void {
    const present_info: vk.PresentInfoKHR = .{
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = @ptrCast(&swapchain.semaphores[swapchain.index]),
        .swapchainCount = 1,
        .pSwapchains = @ptrCast(&swapchain.handle),
        .pImageIndices = @ptrCast(&swapchain.index),
    };
    vk.queuePresentKHR(ctx.queue, &present_info) catch |e| switch (e) {
        error.error_out_of_dateKHR, error.suboptimalKHR => swapchain.should_recreate = true,
        //TODO: https://docs.vulkan.org/spec/latest/chapters/VK_KHR_surface/wsi.html#vkQueuePresentKHR
        else => return error.PresentFailed,
    };
}

fn selectSwapchainFormat(pdevice: vk.PhysicalDevice, surface: vk.SurfaceKHR, formats: []const vk.Format, requirements: vk.FormatFeatureFlags) !vk.SurfaceFormatKHR {
    var format_buffer: [100]vk.SurfaceFormatKHR = undefined;
    var format_count: u32 = format_buffer.len;
    vk.getPhysicalDeviceSurfaceFormatsKHR(pdevice, surface, &format_count, &format_buffer) catch |e| switch (e) {
        error.incomplete => {
            log.warn("Not all surface formats were recieved; Static buffer is too small.", .{});
        },
        else => return error.GetSurfaceFormats,
    };

    for (format_buffer[0..format_count]) |format| {
        var props: vk.FormatProperties2 = .{};
        vk.getPhysicalDeviceFormatProperties2(pdevice, format.format, &props);
        const features: u32 = @bitCast(props.formatProperties.optimalTilingFeatures);
        const reqs: u32 = @bitCast(requirements);
        if (features & reqs >= reqs) for (formats) |f| {
            if (f == format.format) return format;
        };
    }
    return error.NoSurfaceMatch;
}
