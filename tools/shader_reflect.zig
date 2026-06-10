const std = @import("std");

const log = std.log.scoped(.shader_reflect);
const Io = std.Io;

const push_constant_range_buffer_size = 512;

const Kind = enum {
    uniform,
    @"struct",
    scalar,
    vector,
    varyingOutput,
    varyingInput,
};

const Binding = struct {
    kind: Kind,
    offset: ?u32 = null,
    size: ?u32 = null,
};

const Param = struct {
    name: []const u8,
    binding: ?Binding = null,
};

const Stage = enum {
    vertex,
    fragment,
    compute,
};

const EntryPoint = struct {
    name: []const u8,
    stage: Stage,
    threadGroupSize: ?[3]f32 = null,
    parameters: []Param,
};

const Schema = struct {
    entryPoints: []EntryPoint,
};

const gen_header: []const u8 =
    \\const std = @import("std");
    \\const vk = @import("vk");
    \\pub const spirv align(@alignOf(u32)) = @embedFile("spirv").*;
;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const cwd = Io.Dir.cwd();

    if (args.len != 3) {
        fatal("Need json + output file name", .{});
    }

    const reflection_json = cwd.openFile(io, args[1], .{}) catch |err| {
        fatal("unable to create file {s} : {t}", .{ args[1], err });
    };
    defer reflection_json.close(io);
    const shader_gen = cwd.createFile(io, args[2], .{}) catch |err| {
        fatal("unable to create file {s} : {t}", .{ args[2], err });
    };
    defer shader_gen.close(io);

    const size = try reflection_json.length(io);
    const buffer = try arena.alloc(u8, size);
    const read_size = try reflection_json.readPositionalAll(io, buffer, 0);
    std.debug.assert(read_size == size);
    const parsed = try std.json.parseFromSliceLeaky(Schema, arena, buffer, .{ .ignore_unknown_fields = true });

    var push_constants: std.ArrayList(u8) = .empty;
    try push_constants.appendSlice(arena, "pub const push_constant_ranges = [_]vk.PushConstantRange{\n");

    for (parsed.entryPoints) |entry| {
        const stage = entry.stage;
        for (entry.parameters) |param| {
            if (param.binding) |bind| {
                switch (bind.kind) {
                    .uniform => {
                        var b: [128]u8 = @splat(0);
                        const view = try std.fmt.bufPrint(&b, ".{{ .offset = {}, .size = {}, .stageFlags = .{{ .{s} = true}} }},\n", .{ bind.offset.?, bind.size.?, @tagName(stage) });
                        try push_constants.appendSlice(arena, view);
                    },
                    else => {},
                }
            }
        }
        if (entry.threadGroupSize) |thread_dims| {
            var b: [128]u8 = @splat(0);
            const local_size = try std.fmt.bufPrint(&b, "pub const local_size: [3]u32  = .{any};\n", .{thread_dims});
            try shader_gen.writeStreamingAll(io, local_size);
        }
    }

    try push_constants.appendSlice(arena, "};\n");

    try shader_gen.writeStreamingAll(io, gen_header);
    try shader_gen.writeStreamingAll(io, push_constants.items);

    return std.process.cleanExit(io);
}

pub fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    log.err(fmt, args);
    std.process.exit(1);
}
