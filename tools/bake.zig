const std = @import("std");
const log = std.log.scoped(.bake);
const Io = std.Io;

const c = @import("c");
const ktx = @import("ktx");

var exit: std.atomic.Value(bool) = .init(false);

pub fn main(init: std.process.Init) !void {
    var argv = try init.minimal.args.iterateAllocator(init.gpa);
    defer argv.deinit();

    var filepath: []const u8 = undefined;
    var outdir: []const u8 = undefined;
    while (argv.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--model=")) {
            filepath = arg[8.. :0];
        } else if (std.mem.startsWith(u8, arg, "--outdir=")) {
            outdir = arg[9..];
        }
    }

    const import: *const c.aiScene = c.aiImportFile(
        filepath.ptr,
        //TODO test effect of this flags
        c.aiProcess_JoinIdenticalVertices |
            c.aiProcess_ImproveCacheLocality |
            c.aiProcess_RemoveRedundantMaterials |
            c.aiProcess_SplitLargeMeshes |
            c.aiProcess_Triangulate |
            c.aiProcess_OptimizeMeshes |
            // c.aiProcess_OptimizeGraph |
            c.aiProcess_SortByPType |
            c.aiProcess_PreTransformVertices | // this prolly needs to go away
            c.aiProcess_ValidateDataStructure |
            c.aiProcess_FindDegenerates |
            c.aiProcess_FindInvalidData |
            c.aiProcess_FindInstances |
            c.aiProcess_FlipWindingOrder |
            c.aiProcess_FlipUVs,
    ) orelse {
        log.err("{s}", .{c.aiGetErrorString()});
        return error.Assimp;
    };

    if (import.mFlags & c.AI_SCENE_FLAGS_INCOMPLETE != 0) {
        log.err("Incomplete Scene", .{});
        return error.Assimp;
    }

    var scene: *c.aiScene = undefined;
    c.aiCopyScene(import, @ptrCast(&scene));
    defer c.aiFreeScene(scene);
    c.aiReleaseImport(import);

    const scene_root = try Io.Dir.openDir(.cwd(), init.io, Io.Dir.path.dirname(filepath) orelse "./", .{});
    const out = try Io.Dir.openDir(.cwd(), init.io, outdir, .{});

    var group: std.Io.Group = .init;
    defer group.cancel(init.io);

    try processNode(&init, scene_root, scene, scene.mRootNode, out, &group);

    try group.await(init.io);

    const model_format = "gltf2";
    const blob: *const c.aiExportDataBlob = c.aiExportSceneToBlob(scene, model_format, 0) orelse {
        log.err("{s}", .{c.aiGetErrorString()});
        std.process.exit(1);
    };
    defer c.aiReleaseExportBlob(blob);

    var cur_blob: ?*const c.aiExportDataBlob = blob;
    while (cur_blob) |b| {
        const contents: []const u8 = @as([*]u8, @ptrCast(b.data.?))[0..b.size];
        var buf: [256]u8 = undefined;
        const filename = if (b.name.length == 0)
            try std.fmt.bufPrint(&buf, "{s}.gltf", .{Io.Dir.path.stem(filepath)})
        else
            b.name.data[0..b.name.length];

        try out.writeFile(init.io, .{ .sub_path = filename, .data = contents, .flags = .{} });

        cur_blob = b.next;
    }

    if (exit.load(.unordered)) {
        return error.AlreadyReported;
    }
}

pub fn processNode(
    init: *const std.process.Init,
    root: Io.Dir,
    scene: *c.aiScene,
    node: *c.aiNode,
    outdir: Io.Dir,
    group: *std.Io.Group,
) !void {
    for (node.mMeshes[0..node.mNumMeshes]) |mesh| {
        const m: *c.aiMesh = scene.mMeshes[mesh];
        const mat: *c.aiMaterial = scene.mMaterials[m.mMaterialIndex];

        const tex_types: []const u32 = &.{
            c.aiTextureType_BASE_COLOR,
            c.aiTextureType_NORMALS,
            c.aiTextureType_EMISSIVE,
            c.aiTextureType_LIGHTMAP,
            // c.aiTextureType_GLTF_METALLIC_ROUGHNESS,
            c.aiTextureType_DIFFUSE_ROUGHNESS, //it uses this name when exporting for some reason?
        };

        for (tex_types) |t| {
            if (c.aiGetMaterialTextureCount(mat, t) == 0) continue;
            var path: c.aiString = undefined;
            try check(c.aiGetMaterialTexture(mat, t, 0, &path, null, null, null, null, null, null));

            try changeTexturePath(mat, t);

            const slice = try init.gpa.dupe(u8, path.data[0..path.length :0]);
            try group.concurrent(init.io, makeKtxV, .{ init, t, root, slice, outdir });
        }

        // try changeTexturePath(mat, c.aiTextureType_DIFFUSE_ROUGHNESS);
    }

    if (node.mChildren) |children| {
        for (children[0..node.mNumChildren]) |child| {
            try processNode(init, root, scene, child, outdir, group);
        }
    }
}

pub fn changeTexturePath(mat: *const c.aiMaterial, t: u32) !void {
    if (c.aiGetMaterialTextureCount(mat, t) == 0) return;

    var prop: *c.aiMaterialProperty = undefined;
    try check(c.aiGetMaterialProperty(mat, "$tex.file", t, 0, @ptrCast(&prop)));
    var string: *c.aiString = @ptrCast(@alignCast(prop.mData));

    var buf: [256]u8 = undefined;
    const filename = try std.fmt.bufPrintSentinel(&buf, "{s}.ktx2", .{Io.Dir.path.stem(string.data[0..string.length])}, 0);
    string.length = @intCast(filename.len);
    @memcpy(@as([*]u8, &string.data), filename[0 .. filename.len + 1]);
    prop.mDataLength = @intCast(@sizeOf(u32) + filename.len + 1);
}

pub fn check(result: c_int) !void {
    if (result != 0) {
        log.err("{s}", .{c.aiGetErrorString()});
        return error.Assimp;
    }
}

pub const Settings = struct {
    in_format: Format,
    bcn_format: ktx.TranscodeFormat,
    normal_map: bool = false,
    swizzle: [4]u8 = .{ 'r', 'g', 'b', 'a' },
};

pub fn makeKtxV(
    init: *const std.process.Init,
    tex_type: u32,
    indir: Io.Dir,
    path: []const u8,
    outdir: Io.Dir,
) !void {
    makeKtx(init, tex_type, indir, path, outdir) catch |e| switch (e) {
        error.Canceled => |ce| return ce,
        else => {
            log.err("{t}, {s}", .{ e, c.aiTextureTypeToString(tex_type) });
            exit.store(true, .unordered);
        },
    };
}

pub fn makeKtx(
    init: *const std.process.Init,
    tex_type: u32,
    indir: Io.Dir,
    path: []const u8,
    outdir: Io.Dir,
) !void {
    const buffer = try indir.readFileAlloc(init.io, path, init.gpa, .unlimited);
    defer init.gpa.free(buffer);

    var width: i32 = 0;
    var height: i32 = 0;
    var channel_n: i32 = 0;
    const data_ptr = c.stbi_load_from_memory(buffer.ptr, @intCast(buffer.len), &width, &height, &channel_n, 0) orelse {
        log.err("{s} {q}", .{ c.stbi_failure_reason(), path });
        std.process.exit(1);
    };
    defer c.stbi_image_free(data_ptr);
    const data = data_ptr[0..@intCast(width * height * channel_n * @sizeOf(u8))];

    const settings: Settings = switch (tex_type) {
        c.aiTextureType_BASE_COLOR,
        c.aiTextureType_EMISSIVE,
        => .{
            .in_format = switch (channel_n) {
                3 => .r8g8b8_srgb,
                4 => .r8g8b8a8_srgb,
                else => unreachable,
            },
            .bcn_format = .bc7_rgba,
        },
        c.aiTextureType_NORMALS,
        => .{
            .in_format = .r8g8b8_unorm,
            .bcn_format = .bc5_rg,

            .normal_map = true,
        },
        c.aiTextureType_GLTF_METALLIC_ROUGHNESS,
        c.aiTextureType_DIFFUSE_ROUGHNESS,
        => .{
            .in_format = .r8g8b8_unorm,
            .bcn_format = .bc5_rg,
            .swizzle = .{ 'g', 'b', 'b', 'b' },
        },
        c.aiTextureType_LIGHTMAP,
        => .{
            .in_format = .r8g8b8_unorm,
            .bcn_format = .bc4_r,
        },
        else => unreachable,
    };

    const ci: ktx.Texture.CreateInfo = .{
        .vkFormat = @intFromEnum(settings.in_format),
        .baseWidth = @intCast(width),
        .baseHeight = @intCast(height),
        .numDimensions = 2,
        .baseDepth = 1,
        .numLevels = 1,
        .numLayers = 1,
        .numFaces = 1,
        .isArray = false,
        .generateMipmaps = false,
    };
    const texture: *ktx.Texture = try .create(&ci, .alloc_storage);
    defer texture.destroy();

    try texture.setImageFromMemory(0, 0, 0, data);

    var params: ktx.BasisParams = .{
        .uastc = true,
        .threadCount = 1,
        .uastcRDO = false,
        .uastcFlags = .level_fastest,
        .normalMap = settings.normal_map,
        .inputSwizzle = settings.swizzle,
    };
    try texture.compressBasisEx(&params);
    try texture.transcodeBasis(settings.bcn_format, @enumFromInt(0));
    try texture.deflateZstd(1);

    const ktx_contents = try texture.writeToMemory();
    defer std.heap.c_allocator.free(ktx_contents);

    var buf: [256]u8 = @splat(0);
    const new_path = try std.fmt.bufPrint(&buf, "{s}.ktx2", .{Io.Dir.path.stem(path)});
    try outdir.writeFile(init.io, .{ .sub_path = new_path, .data = ktx_contents, .flags = .{} });

    init.gpa.free(path);
}

pub const Format = enum(u32) {
    undefined = 0,
    r4g4_unorm_pack8 = 1,
    r4g4b4a4_unorm_pack16 = 2,
    b4g4r4a4_unorm_pack16 = 3,
    r5g6b5_unorm_pack16 = 4,
    b5g6r5_unorm_pack16 = 5,
    r5g5b5a1_unorm_pack16 = 6,
    b5g5r5a1_unorm_pack16 = 7,
    a1r5g5b5_unorm_pack16 = 8,
    r8_unorm = 9,
    r8_snorm = 10,
    r8_uscaled = 11,
    r8_sscaled = 12,
    r8_uint = 13,
    r8_sint = 14,
    r8_srgb = 15,
    r8g8_unorm = 16,
    r8g8_snorm = 17,
    r8g8_uscaled = 18,
    r8g8_sscaled = 19,
    r8g8_uint = 20,
    r8g8_sint = 21,
    r8g8_srgb = 22,
    r8g8b8_unorm = 23,
    r8g8b8_snorm = 24,
    r8g8b8_uscaled = 25,
    r8g8b8_sscaled = 26,
    r8g8b8_uint = 27,
    r8g8b8_sint = 28,
    r8g8b8_srgb = 29,
    b8g8r8_unorm = 30,
    b8g8r8_snorm = 31,
    b8g8r8_uscaled = 32,
    b8g8r8_sscaled = 33,
    b8g8r8_uint = 34,
    b8g8r8_sint = 35,
    b8g8r8_srgb = 36,
    r8g8b8a8_unorm = 37,
    r8g8b8a8_snorm = 38,
    r8g8b8a8_uscaled = 39,
    r8g8b8a8_sscaled = 40,
    r8g8b8a8_uint = 41,
    r8g8b8a8_sint = 42,
    r8g8b8a8_srgb = 43,
    b8g8r8a8_unorm = 44,
    b8g8r8a8_snorm = 45,
    b8g8r8a8_uscaled = 46,
    b8g8r8a8_sscaled = 47,
    b8g8r8a8_uint = 48,
    b8g8r8a8_sint = 49,
    b8g8r8a8_srgb = 50,
    a8b8g8r8_unorm_pack32 = 51,
    a8b8g8r8_snorm_pack32 = 52,
    a8b8g8r8_uscaled_pack32 = 53,
    a8b8g8r8_sscaled_pack32 = 54,
    a8b8g8r8_uint_pack32 = 55,
    a8b8g8r8_sint_pack32 = 56,
    a8b8g8r8_srgb_pack32 = 57,
    a2r10g10b10_unorm_pack32 = 58,
    a2r10g10b10_snorm_pack32 = 59,
    a2r10g10b10_uscaled_pack32 = 60,
    a2r10g10b10_sscaled_pack32 = 61,
    a2r10g10b10_uint_pack32 = 62,
    a2r10g10b10_sint_pack32 = 63,
    a2b10g10r10_unorm_pack32 = 64,
    a2b10g10r10_snorm_pack32 = 65,
    a2b10g10r10_uscaled_pack32 = 66,
    a2b10g10r10_sscaled_pack32 = 67,
    a2b10g10r10_uint_pack32 = 68,
    a2b10g10r10_sint_pack32 = 69,
    r16_unorm = 70,
    r16_snorm = 71,
    r16_uscaled = 72,
    r16_sscaled = 73,
    r16_uint = 74,
    r16_sint = 75,
    r16_sfloat = 76,
    r16g16_unorm = 77,
    r16g16_snorm = 78,
    r16g16_uscaled = 79,
    r16g16_sscaled = 80,
    r16g16_uint = 81,
    r16g16_sint = 82,
    r16g16_sfloat = 83,
    r16g16b16_unorm = 84,
    r16g16b16_snorm = 85,
    r16g16b16_uscaled = 86,
    r16g16b16_sscaled = 87,
    r16g16b16_uint = 88,
    r16g16b16_sint = 89,
    r16g16b16_sfloat = 90,
    r16g16b16a16_unorm = 91,
    r16g16b16a16_snorm = 92,
    r16g16b16a16_uscaled = 93,
    r16g16b16a16_sscaled = 94,
    r16g16b16a16_uint = 95,
    r16g16b16a16_sint = 96,
    r16g16b16a16_sfloat = 97,
    r32_uint = 98,
    r32_sint = 99,
    r32_sfloat = 100,
    r32g32_uint = 101,
    r32g32_sint = 102,
    r32g32_sfloat = 103,
    r32g32b32_uint = 104,
    r32g32b32_sint = 105,
    r32g32b32_sfloat = 106,
    r32g32b32a32_uint = 107,
    r32g32b32a32_sint = 108,
    r32g32b32a32_sfloat = 109,
    r64_uint = 110,
    r64_sint = 111,
    r64_sfloat = 112,
    r64g64_uint = 113,
    r64g64_sint = 114,
    r64g64_sfloat = 115,
    r64g64b64_uint = 116,
    r64g64b64_sint = 117,
    r64g64b64_sfloat = 118,
    r64g64b64a64_uint = 119,
    r64g64b64a64_sint = 120,
    r64g64b64a64_sfloat = 121,
    b10g11r11_ufloat_pack32 = 122,
    e5b9g9r9_ufloat_pack32 = 123,
    d16_unorm = 124,
    x8_d24_unorm_pack32 = 125,
    d32_sfloat = 126,
    s8_uint = 127,
    d16_unorm_s8_uint = 128,
    d24_unorm_s8_uint = 129,
    d32_sfloat_s8_uint = 130,
    bc1_rgb_unorm_block = 131,
    bc1_rgb_srgb_block = 132,
    bc1_rgba_unorm_block = 133,
    bc1_rgba_srgb_block = 134,
    bc2_unorm_block = 135,
    bc2_srgb_block = 136,
    bc3_unorm_block = 137,
    bc3_srgb_block = 138,
    bc4_unorm_block = 139,
    bc4_snorm_block = 140,
    bc5_unorm_block = 141,
    bc5_snorm_block = 142,
    bc6h_ufloat_block = 143,
    bc6h_sfloat_block = 144,
    bc7_unorm_block = 145,
    bc7_srgb_block = 146,
    etc2_r8g8b8_unorm_block = 147,
    etc2_r8g8b8_srgb_block = 148,
    etc2_r8g8b8a1_unorm_block = 149,
    etc2_r8g8b8a1_srgb_block = 150,
    etc2_r8g8b8a8_unorm_block = 151,
    etc2_r8g8b8a8_srgb_block = 152,
    eac_r11_unorm_block = 153,
    eac_r11_snorm_block = 154,
    eac_r11g11_unorm_block = 155,
    eac_r11g11_snorm_block = 156,
    astc_4x4_unorm_block = 157,
    astc_4x4_srgb_block = 158,
    astc_5x4_unorm_block = 159,
    astc_5x4_srgb_block = 160,
    astc_5x5_unorm_block = 161,
    astc_5x5_srgb_block = 162,
    astc_6x5_unorm_block = 163,
    astc_6x5_srgb_block = 164,
    astc_6x6_unorm_block = 165,
    astc_6x6_srgb_block = 166,
    astc_8x5_unorm_block = 167,
    astc_8x5_srgb_block = 168,
    astc_8x6_unorm_block = 169,
    astc_8x6_srgb_block = 170,
    astc_8x8_unorm_block = 171,
    astc_8x8_srgb_block = 172,
    astc_10x5_unorm_block = 173,
    astc_10x5_srgb_block = 174,
    astc_10x6_unorm_block = 175,
    astc_10x6_srgb_block = 176,
    astc_10x8_unorm_block = 177,
    astc_10x8_srgb_block = 178,
    astc_10x10_unorm_block = 179,
    astc_10x10_srgb_block = 180,
    astc_12x10_unorm_block = 181,
    astc_12x10_srgb_block = 182,
    astc_12x12_unorm_block = 183,
    astc_12x12_srgb_block = 184,
    g8b8g8r8_422_unorm = 1000156000,
    b8g8r8g8_422_unorm = 1000156001,
    g8_b8_r8_3plane_420_unorm = 1000156002,
    g8_b8r8_2plane_420_unorm = 1000156003,
    g8_b8_r8_3plane_422_unorm = 1000156004,
    g8_b8r8_2plane_422_unorm = 1000156005,
    g8_b8_r8_3plane_444_unorm = 1000156006,
    r10x6_unorm_pack16 = 1000156007,
    r10x6g10x6_unorm_2pack16 = 1000156008,
    r10x6g10x6b10x6a10x6_unorm_4pack16 = 1000156009,
    g10x6b10x6g10x6r10x6_422_unorm_4pack16 = 1000156010,
    b10x6g10x6r10x6g10x6_422_unorm_4pack16 = 1000156011,
    g10x6_b10x6_r10x6_3plane_420_unorm_3pack16 = 1000156012,
    g10x6_b10x6r10x6_2plane_420_unorm_3pack16 = 1000156013,
    g10x6_b10x6_r10x6_3plane_422_unorm_3pack16 = 1000156014,
    g10x6_b10x6r10x6_2plane_422_unorm_3pack16 = 1000156015,
    g10x6_b10x6_r10x6_3plane_444_unorm_3pack16 = 1000156016,
    r12x4_unorm_pack16 = 1000156017,
    r12x4g12x4_unorm_2pack16 = 1000156018,
    r12x4g12x4b12x4a12x4_unorm_4pack16 = 1000156019,
    g12x4b12x4g12x4r12x4_422_unorm_4pack16 = 1000156020,
    b12x4g12x4r12x4g12x4_422_unorm_4pack16 = 1000156021,
    g12x4_b12x4_r12x4_3plane_420_unorm_3pack16 = 1000156022,
    g12x4_b12x4r12x4_2plane_420_unorm_3pack16 = 1000156023,
    g12x4_b12x4_r12x4_3plane_422_unorm_3pack16 = 1000156024,
    g12x4_b12x4r12x4_2plane_422_unorm_3pack16 = 1000156025,
    g12x4_b12x4_r12x4_3plane_444_unorm_3pack16 = 1000156026,
    g16b16g16r16_422_unorm = 1000156027,
    b16g16r16g16_422_unorm = 1000156028,
    g16_b16_r16_3plane_420_unorm = 1000156029,
    g16_b16r16_2plane_420_unorm = 1000156030,
    g16_b16_r16_3plane_422_unorm = 1000156031,
    g16_b16r16_2plane_422_unorm = 1000156032,
    g16_b16_r16_3plane_444_unorm = 1000156033,
    g8_b8r8_2plane_444_unorm = 1000330000,
    g10x6_b10x6r10x6_2plane_444_unorm_3pack16 = 1000330001,
    g12x4_b12x4r12x4_2plane_444_unorm_3pack16 = 1000330002,
    g16_b16r16_2plane_444_unorm = 1000330003,
    a4r4g4b4_unorm_pack16 = 1000340000,
    a4b4g4r4_unorm_pack16 = 1000340001,
    astc_4x4_sfloat_block = 1000066000,
    astc_5x4_sfloat_block = 1000066001,
    astc_5x5_sfloat_block = 1000066002,
    astc_6x5_sfloat_block = 1000066003,
    astc_6x6_sfloat_block = 1000066004,
    astc_8x5_sfloat_block = 1000066005,
    astc_8x6_sfloat_block = 1000066006,
    astc_8x8_sfloat_block = 1000066007,
    astc_10x5_sfloat_block = 1000066008,
    astc_10x6_sfloat_block = 1000066009,
    astc_10x8_sfloat_block = 1000066010,
    astc_10x10_sfloat_block = 1000066011,
    astc_12x10_sfloat_block = 1000066012,
    astc_12x12_sfloat_block = 1000066013,
};
