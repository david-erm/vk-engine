const vk = @import("vk");
const std = @import("std");

pub const VulkanFunctions = extern struct {
    vkGetInstanceProcAddr: ?vk.pfn.vkGetInstanceProcAddr = null,
    vkGetDeviceProcAddr: ?vk.pfn.vkGetDeviceProcAddr = null,
    vkGetPhysicalDeviceProperties: ?vk.pfn.vkGetPhysicalDeviceProperties = null,
    vkGetPhysicalDeviceMemoryProperties: ?vk.pfn.vkGetPhysicalDeviceMemoryProperties = null,
    vkAllocateMemory: ?vk.pfn.vkAllocateMemory = null,
    vkFreeMemory: ?vk.pfn.vkFreeMemory = null,
    vkMapMemory: ?vk.pfn.vkMapMemory = null,
    vkUnmapMemory: ?vk.pfn.vkUnmapMemory = null,
    vkFlushMappedMemoryRanges: ?vk.pfn.vkFlushMappedMemoryRanges = null,
    vkInvalidateMappedMemoryRanges: ?vk.pfn.vkInvalidateMappedMemoryRanges = null,
    vkBindBufferMemory: ?vk.pfn.vkBindBufferMemory = null,
    vkBindImageMemory: ?vk.pfn.vkBindImageMemory = null,
    vkGetBufferMemoryRequirements: ?vk.pfn.vkGetBufferMemoryRequirements = null,
    vkGetImageMemoryRequirements: ?vk.pfn.vkGetImageMemoryRequirements = null,
    vkCreateBuffer: ?vk.pfn.vkCreateBuffer = null,
    vkDestroyBuffer: ?vk.pfn.vkDestroyBuffer = null,
    vkCreateImage: ?vk.pfn.vkCreateImage = null,
    vkDestroyImage: ?vk.pfn.vkDestroyImage = null,
    vkCmdCopyBuffer: ?vk.pfn.vkCmdCopyBuffer = null,
    vkGetBufferMemoryRequirements2KHR: ?*anyopaque = null,
    vkGetImageMemoryRequirements2KHR: ?*anyopaque = null,
    vkBindBufferMemory2KHR: ?*anyopaque = null,
    vkBindImageMemory2KHR: ?*anyopaque = null,
    vkGetPhysicalDeviceMemoryProperties2KHR: ?*anyopaque = null,
    vkGetDeviceBufferMemoryRequirements: ?*anyopaque = null,
    vkGetDeviceImageMemoryRequirements: ?*anyopaque = null,
    vkGetMemoryWin32HandleKHR: ?*anyopaque = undefined,
};

pub const AllocatorCreateFlags = packed struct(u32) {
    ExternallySynchronizedBit: u1 = 0,
    KHRDedicatedAllocationBit: u1 = 0,
    KHRBindMemory2Bit: u1 = 0,
    EXTMemoryBudgetBit: u1 = 0,
    AMDDeviceCoherentmemoryBit: u1 = 0,
    BufferDeviceAddressBit: u1 = 0,
    EXTMemoryPriorityBit: u1 = 0,
    KHRMaintenance4Bit: u1 = 0,
    KHRMaintenance5Bit: u1 = 0,
    KHRExternalMemoryWin32Bit: u1 = 0,
    reserved: u22 = 0,
};

pub const AllocationCreateFlags = packed struct(u32) {
    dedicated_memory_bit: bool = false,
    never_allocate_bit: bool = false,
    mapped_bit: bool = false,
    _padding1: u2 = 0,
    user_data_copy_string_bit: bool = false,
    upper_address_bit: bool = false,
    dont_bind_bit: bool = false,
    within_budget_bit: bool = false,
    can_alias_bit: bool = false,
    host_access_sequential_write_bit: bool = false,
    host_access_random_bit: bool = false,
    host_access_allow_transfer_instead_bit: bool = false,
    _padding2: u3 = 0,
    strategy_min_memory_bit: bool = false,
    strategy_min_time_bit: bool = false,
    strategy_min_offset_bit: bool = false,
    strategy_best_fit_bit: bool = false,
    strategy_first_fit_bit: bool = false,
    strategy_mask: bool = false,
    flag_bits_max_enum: bool = false,
    reserved: u9 = 0,
};

pub const MemoryUsage = enum(u32) {
    unknown,
    gpu_only,
    cpu_only,
    cpu_to_gpu,
    gpu_to_cpu,
    cpu_copy,
    gpu_lazily_allocated,
    auto,
    auto_prefer_device,
    auto_prefer_host,
};

pub const AllocationCreateInfo = extern struct {
    flags: AllocationCreateFlags = .{},
    usage: MemoryUsage = @import("std").mem.zeroes(MemoryUsage),
    requiredFlags: vk.MemoryPropertyFlags = .{},
    preferredFlags: vk.MemoryPropertyFlags = .{},
    memoryTypeBits: u32 = 0,
    pool: ?Pool = null,
    pUserData: ?*anyopaque = null,
    priority: f32 = 0,

    //some easy defaults
    pub const mapped_vram: AllocationCreateInfo = .{ .usage = .auto, .flags = .{ .mapped_bit = true, .host_access_sequential_write_bit = true, .host_access_allow_transfer_instead_bit = true } };
};

pub const AllocationInfo = extern struct {
    memoryType: u32 = 0,
    deviceMemory: ?vk.DeviceMemory = null,
    offset: vk.DeviceSize = 0,
    size: vk.DeviceSize = 0,
    pMappedData: ?*anyopaque = null,
    pUserData: ?*anyopaque = null,
    pName: ?[*:0]const u8 = null,
};

const Allocator_t = opaque {};
pub const Allocator = *Allocator_t;
const Pool_t = opaque {};
pub const Pool = *Pool_t;
const Allocation_t = opaque {};
pub const Allocation = *Allocation_t;

pub const AllocateDeviceMemoryFunction_PFN = ?*const fn (allocator: Allocator, memoryType: u32, memory: vk.DeviceMemory, size: u64, pUserData: ?*anyopaque) callconv(.c) void;
pub const FreeDeviceMemoryFunction_PFN = ?*const fn (allocator: Allocator, memoryType: u32, memory: vk.DeviceMemory, size: u64, pUserData: ?*anyopaque) callconv(.c) void;

pub const DeviceMemoryCallbacks = extern struct {
    pfnAllocate: AllocateDeviceMemoryFunction_PFN = null,
    pfnFree: FreeDeviceMemoryFunction_PFN = null,
    pUserData: ?*anyopaque = null,
};

pub const AllocatorCreateInfo = extern struct {
    flags: AllocatorCreateFlags = std.mem.zeroes(AllocatorCreateFlags),
    physicalDevice: vk.PhysicalDevice,
    device: vk.Device,
    preferredLargeHeapBlockSize: vk.DeviceSize = 0,
    pAllocationCallbacks: [*c]const vk.AllocationCallbacks = null,
    pDeviceMemoryCallbacks: [*c]const DeviceMemoryCallbacks = null,
    pHeapSizeLimit: [*c]const vk.DeviceSize = null,
    pVulkanFunctions: [*c]const VulkanFunctions = null,
    instance: vk.Instance,
    vulkanApiVersion: u32 = 0,
    pTypeExternalMemoryHandleTypes: [*c]const vk.ExternalMemoryHandleTypeFlags = null,
};

pub const createAllocator = @extern(*const fn (*const AllocatorCreateInfo, *Allocator) callconv(.c) vk.Result, .{ .name = "vmaCreateAllocator" });
pub const destroyAllocator = @extern(*const fn (Allocator) callconv(.c) void, .{ .name = "vmaDestroyAllocator" });
pub const createImage = @extern(*const fn (allocator: Allocator, imageCreateInfo: *const vk.ImageCreateInfo, *const AllocationCreateInfo, image: *vk.Image, allocation: *Allocation, allocationInfo: ?*AllocationInfo) callconv(.c) vk.Result, .{ .name = "vmaCreateImage" });
pub const destroyImage = @extern(*const fn (allocator: Allocator, img: vk.Image, allocation: Allocation) callconv(.c) void, .{ .name = "vmaDestroyImage" });
pub const createBuffer = @extern(*const fn (allocator: Allocator, buffer_create_info: *const vk.BufferCreateInfo, *const AllocationCreateInfo, buffer: *vk.Buffer, allocation: *Allocation, allocationInfo: ?*AllocationInfo) callconv(.c) vk.Result, .{ .name = "vmaCreateBuffer" });
pub const destroyBuffer = @extern(*const fn (allocator: Allocator, buffer: vk.Buffer, allocation: Allocation) callconv(.c) void, .{ .name = "vmaDestroyBuffer" });
