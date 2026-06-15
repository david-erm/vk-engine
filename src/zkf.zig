const std = @import("std");
const Io = std.Io;

const vk = @import("vk");
const gltf = @import("zgltf").Gltf;
const sdl = @import("sdl.zig");
const vma = @import("vma.zig");
const ktx = @import("ktx.zig");
const math = @import("math.zig");

pub const Vec3 = math.Vec3;
pub const Quat = math.Quat;

const vk_extensions = @import("vk_extensions");

pub const AssetManager = @import("AssetManager.zig");

const log = std.log.scoped(.howtovulkan);

pub fn makeError(err: type, ret: anytype) err!void {
    switch (ret) {
        @enumFromInt(0) => {
            return;
        },
        inline else => |t| {
            return @field(err, @tagName(t));
        },
    }
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

        var queue_count: u32 = 0;
        ctx.qfamily = 0;
        vk.getPhysicalDeviceQueueFamilyProperties(ctx.pdevice, &queue_count, null);
        const queue_families = try arena.alloc(vk.QueueFamilyProperties, queue_count);
        vk.getPhysicalDeviceQueueFamilyProperties(ctx.pdevice, &queue_count, queue_families.ptr);
        while (!(queue_families[ctx.qfamily].queueFlags.graphics and queue_families[ctx.qfamily].queueFlags.compute)) : (ctx.qfamily += 1) {}
        try sdl.vulkan.getPresentationSupport(ctx.instance, ctx.pdevice, ctx.qfamily);

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
