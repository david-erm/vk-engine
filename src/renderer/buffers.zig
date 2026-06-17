const std = @import("std");
const log = std.log.scoped(.Renderer);

const vk = @import("vk");
const vma = @import("../vma.zig");

pub const Bump = struct {
    handle: vk.Buffer,
    alloc: vma.Allocation,
    data: []u8,

    pub fn init() void {}
};

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
