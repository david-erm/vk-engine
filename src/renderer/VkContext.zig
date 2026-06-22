const std = @import("std");
const log = std.log.scoped(.vkcontext);

const vk = @import("vk");
//NOTE: vma considered vk context for now, could decomple this as well
const vma = @import("../vma.zig");

//NOTE: Multiple queues might be needed, will need to change this if so
pub const Context = struct {
    instance: vk.Instance,
    pdevice: vk.PhysicalDevice,
    device: vk.Device,
    queue: vk.Queue,
    vka: vma.Allocator,
    qfamily: u32,

    pub fn deinit(ctx: *Context) void {
        vma.destroyAllocator(ctx.vka);
        vk.destroyDevice(ctx.device, null);
        vk.destroyInstance(ctx.instance, null);
    }

    pub fn init(gpa: std.mem.Allocator, instance_extensions: []const [*:0]const u8, device_extensions: []const [*:0]const u8, proc_addr: vk.pfn.vkGetInstanceProcAddr) !Context {
        var ctx: Context = undefined;
        vk.load(proc_addr);

        const app_info: vk.ApplicationInfo = .{
            .apiVersion = vk.makeApiVersion(0, 1, 3, 0),
            .pApplicationName = "howtovulkna",
            .applicationVersion = vk.makeApiVersion(0, 1, 0, 0),
            .pEngineName = "zkf",
            .engineVersion = vk.makeApiVersion(0, 1, 0, 0),
        };
        try vk.createInstance(&.{
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = @intCast(instance_extensions.len),
            .ppEnabledExtensionNames = instance_extensions.ptr,
        }, null, &ctx.instance);

        vk.loadInstance(ctx.instance);

        var device_count: u32 = 0;
        try vk.enumeratePhysicalDevices(ctx.instance, &device_count, null);
        const devices = try gpa.alloc(vk.PhysicalDevice, device_count);
        defer gpa.free(devices);
        try vk.enumeratePhysicalDevices(ctx.instance, &device_count, devices.ptr);
        const device_index: u32 = 0;
        ctx.pdevice = devices[device_index];

        for (devices) |d| {
            var dp: vk.PhysicalDeviceProperties2 = .{};
            vk.getPhysicalDeviceProperties2(d, &dp);
            var features: vk.PhysicalDeviceFeatures2 = .{};
            vk.getPhysicalDeviceFeatures2(d, &features);
        }

        var device_properties: vk.PhysicalDeviceProperties2 = .{};
        vk.getPhysicalDeviceProperties2(devices[device_index], &device_properties);
        log.info("Selected device: {s}", .{device_properties.properties.deviceName});

        var queue_count: u32 = 0;
        ctx.qfamily = 0;
        vk.getPhysicalDeviceQueueFamilyProperties(ctx.pdevice, &queue_count, null);
        const queue_families = try gpa.alloc(vk.QueueFamilyProperties, queue_count);
        defer gpa.free(queue_families);
        vk.getPhysicalDeviceQueueFamilyProperties(ctx.pdevice, &queue_count, queue_families.ptr);
        while (!(queue_families[ctx.qfamily].queueFlags.graphics and queue_families[ctx.qfamily].queueFlags.compute)) : (ctx.qfamily += 1) {}

        const qfpriorities: [1]f32 = .{1.0};
        const queueCI: vk.DeviceQueueCreateInfo = .{
            .queueFamilyIndex = ctx.qfamily,
            .queueCount = 1,
            .pQueuePriorities = &qfpriorities,
        };
        var enableVK12Features: vk.PhysicalDeviceVulkan12Features = .{
            .descriptorIndexing = .True,
            .runtimeDescriptorArray = .True,
            .bufferDeviceAddress = .True,
            .timelineSemaphore = .True,
            .scalarBlockLayout = .True,
            .shaderSampledImageArrayNonUniformIndexing = .True,
            .descriptorBindingPartiallyBound = .True,
            .descriptorBindingUpdateUnusedWhilePending = .True,
        };
        const enableVK13Features: vk.PhysicalDeviceVulkan13Features = .{
            .pNext = &enableVK12Features,
            .synchronization2 = .True,
            .dynamicRendering = .True,
        };
        const enableVKFeatures: vk.PhysicalDeviceFeatures = .{
            .samplerAnisotropy = .True,
            .shaderInt64 = .True,
        };
        try vk.createDevice(ctx.pdevice, &.{
            .pNext = &enableVK13Features,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = @ptrCast(&queueCI),
            .enabledExtensionCount = @intCast(device_extensions.len),
            .ppEnabledExtensionNames = device_extensions.ptr,
            .pEnabledFeatures = &enableVKFeatures,
        }, null, &ctx.device);
        vk.loadDevice(ctx.device);
        vk.getDeviceQueue(ctx.device, ctx.qfamily, 0, &ctx.queue);

        const vkFuncs: vma.VulkanFunctions = .{
            .vkGetInstanceProcAddr = vk.table.instance.vkGetInstanceProcAddr,
            .vkGetDeviceProcAddr = vk.table.device.vkGetDeviceProcAddr,
        };
        try vma.createAllocator(&.{
            .flags = .{ .BufferDeviceAddressBit = 1 },
            .physicalDevice = ctx.pdevice,
            .device = ctx.device,
            .pVulkanFunctions = &vkFuncs,
            .instance = ctx.instance,
        }, &ctx.vka);

        return ctx;
    }
};
