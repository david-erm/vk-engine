const std = @import("std");

const vk = @import("vk");
const vma = @import("vma.zig");

const root = @import("gfx.zig");

pub const TimelineSemaphore = struct {
    const tci: vk.SemaphoreTypeCreateInfo = .{ .semaphoreType = .timeline };
    const ci: vk.SemaphoreCreateInfo = .{ .pNext = &tci };

    handle: vk.Semaphore,
    val: u64,

    pub fn deinit(smp: TimelineSemaphore, device: vk.Device) void {
        vk.destroySemaphore(device, smp.handle, null);
    }

    pub fn init(device: vk.Device) !TimelineSemaphore {
        var tml_semaphore: TimelineSemaphore = undefined;
        try vk.createSemaphore(device, &ci, null, &tml_semaphore.handle);
        tml_semaphore.val = 0;
        return tml_semaphore;
    }
};

pub fn GpuMapped(T: type) type {
    return struct {
        const allocation_info: vma.AllocationCreateInfo = .mapped_vram;
        handle: vk.Buffer,
        alloc: vma.Allocation,
        data: []T,

        pub fn deinit(map: *const @This(), vka: vma.Allocator) void {
            vma.destroyBuffer(vka, map.handle, map.alloc);
        }

        pub fn init(vka: vma.Allocator, ci: *const vk.BufferCreateInfo) !@This() {
            var map: @This() = undefined;
            var alloci: vma.AllocationInfo = undefined;
            try vma.createBuffer(vka, ci, &allocation_info, &map.handle, &map.alloc, &alloci);
            if (alloci.pMappedData) |ptr| {
                map.data = @as([*]T, @ptrCast(@alignCast(ptr)))[0 .. ci.size / @sizeOf(T)];
            } else return error.NotMapped;
            return map;
        }
    };
}

pub fn GpuMappedPush(T: type) type {
    return struct {
        buff: GpuMapped(T),
        offset: u64,

        pub fn deinit(push: *const @This(), vka: vma.Allocator) void {
            push.buff.deinit(vka);
        }

        pub fn init(vka: vma.Allocator, size: u64, usage: vk.BufferUsageFlags) !@This() {
            const ci: vk.BufferCreateInfo = .{
                .size = size * @sizeOf(T),
                .usage = usage,
            };
            var push: @This() = undefined;
            push.buff = try .init(vka, &ci);
            push.offset = 0;

            return push;
        }

        pub fn append(push: *@This(), data: T) void {
            push.buff.data[push.offset] = data;
            push.offset += 1;
        }

        pub fn appendSlice(push: *@This(), data: []const T) void {
            @memcpy(push.buff.data.ptr + push.offset, data);
            push.offset += data.len;
        }

        pub fn reset(push: *@This()) void {
            push.offset = 0;
        }

        pub fn handle(push: *const @This()) vk.Buffer {
            return push.buff.handle;
        }

        pub fn bda(push: *const @This(), device: vk.Device) vk.DeviceAddress {
            return vk.getBufferDeviceAddress(device, &.{ .buffer = push.handle() });
        }
    };
}

pub const DescriptorManager = struct {
    const flags: vk.DescriptorBindingFlags = .{ .partially_bound = true, .update_unused_while_pending = true };
    const desc_bind_flags: vk.DescriptorSetLayoutBindingFlagsCreateInfo = .{
        .pBindingFlags = &@as([3]vk.DescriptorBindingFlags, @splat(flags)),
        .bindingCount = 3,
    };
    const max_sampled = root.max_sampled;
    const max_storage = root.max_storage;
    const max_sampler = root.max_sampler;

    set: vk.DescriptorSet,
    layout: vk.DescriptorSetLayout,
    pool: vk.DescriptorPool,

    current_sampled: u32,
    current_storage: u32,
    current_sampler: u32,

    //FIX: worry about freeing slots later
    // sampled_free: std.SinglyLinkedList,
    // sampler_free: std.SinglyLinkedList,
    // storage_free: std.SinglyLinkedList,

    pub fn deinit(ring: *DescriptorManager, device: vk.Device) void {
        vk.destroyDescriptorPool(device, ring.pool, null);
        vk.destroyDescriptorSetLayout(device, ring.layout, null);
    }

    pub fn init(device: vk.Device) !DescriptorManager {
        var ring: DescriptorManager = undefined;
        ring.current_sampled = 0;
        ring.current_storage = 0;
        ring.current_sampler = 0;
        const bindings = [_]vk.DescriptorSetLayoutBinding{
            .{
                .binding = 0,
                .descriptorCount = max_sampled,
                .descriptorType = .sampled_image,
                .stageFlags = .{ .fragment = true, .vertex = true, .compute = true },
            },
            .{
                .binding = 1,
                .descriptorCount = max_storage,
                .descriptorType = .storage_image,
                .stageFlags = .{ .fragment = true, .vertex = true, .compute = true },
            },
            .{
                .binding = 2,
                .descriptorCount = max_sampler,
                .descriptorType = .sampler,
                .stageFlags = .{ .fragment = true, .vertex = true, .compute = true },
            },
        };
        const desc_layout_ci: vk.DescriptorSetLayoutCreateInfo = .{
            .pNext = &desc_bind_flags,
            .pBindings = &bindings,
            .bindingCount = 3,
        };
        try vk.createDescriptorSetLayout(device, &desc_layout_ci, null, &ring.layout);

        const sizes: []const vk.DescriptorPoolSize = &.{
            .{ .descriptorCount = max_sampled, .type = .sampled_image },
            .{ .descriptorCount = max_storage, .type = .storage_image },
            .{ .descriptorCount = max_sampler, .type = .sampler },
        };
        const pool_ci: vk.DescriptorPoolCreateInfo = .{
            .maxSets = 1,
            .poolSizeCount = @intCast(sizes.len),
            .pPoolSizes = sizes.ptr,
        };
        try vk.createDescriptorPool(device, &pool_ci, null, &ring.pool);

        const set_ai: vk.DescriptorSetAllocateInfo = .{
            .descriptorPool = ring.pool,
            .descriptorSetCount = 1,
            .pSetLayouts = @ptrCast(&ring.layout),
        };
        try vk.allocateDescriptorSets(device, &set_ai, @ptrCast(&ring.set));

        return ring;
    }

    pub fn appendSampled(ring: *DescriptorManager, device: vk.Device, view: vk.ImageView, layout: vk.ImageLayout) u32 {
        const write: vk.WriteDescriptorSet = .{
            .dstSet = ring.set,
            .dstBinding = 0,
            .descriptorType = .sampled_image,
            .dstArrayElement = ring.current_sampled,
            .descriptorCount = 1,
            .pImageInfo = &.{.{ .imageView = view, .imageLayout = layout }},
        };
        vk.updateDescriptorSets(device, 1, @ptrCast(&write), 0, undefined);
        const idx = ring.current_sampled;
        ring.current_sampled += 1;
        return idx;
    }

    pub fn appendStorage(ring: *DescriptorManager, device: vk.Device, view: vk.ImageView, layout: vk.ImageLayout) u32 {
        const write: vk.WriteDescriptorSet = .{
            .dstSet = ring.set,
            .dstBinding = 1,
            .descriptorType = .storage_image,
            .dstArrayElement = ring.current_storage,
            .descriptorCount = 1,
            .pImageInfo = &.{.{ .imageView = view, .imageLayout = layout }},
        };
        vk.updateDescriptorSets(device, 1, @ptrCast(&write), 0, undefined);
        const idx = ring.current_storage;
        ring.current_storage += 1;
        return idx;
    }

    pub fn appendSampler(ring: *DescriptorManager, device: vk.Device, sampler: vk.Sampler) u32 {
        const write: vk.WriteDescriptorSet = .{
            .dstSet = ring.set,
            .dstBinding = 2,
            .descriptorType = .sampler,
            .dstArrayElement = ring.sampler,
            .descriptorCount = 1,
            .pImageInfo = &.{.{ .sampler = sampler }},
        };
        vk.updateDescriptorSets(device, 1, @ptrCast(&write), 0, undefined);
        const idx = ring.current_sampler;
        ring.current_sampler += 1;
        return idx;
    }

    // pub fn reset(ring: *DescriptorManager) void {
    //     ring.current_sampled = 0;
    //     ring.current_storage = 0;
    //     ring.current_sampler = 0;
    // }
};
