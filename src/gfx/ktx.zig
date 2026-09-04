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

pub const ErrorEnum = enum(u32) {
    Success = 0,
    FileData,
    FileIspipe,
    FileOpenFailed,
    FileOverflow,
    FileRead,
    FileSeek,
    FileUnexpectedEOF,
    FileWrite,
    Gl,
    InvalidOperation,
    InvalidValue,
    NotFound,
    OutOfMemory,
    TranscodeFailed,
    UnknownFileFormat,
    UnsupportedTexturetype,
    UnsupportedFeature,
    LibraryNotLinked,
    DecompressLength,
    DecompressChecksum,
};

pub const Error = error{
    FileData,
    FileIspipe,
    FileOpenFailed,
    FileOverflow,
    FileRead,
    FileSeek,
    FileUnexpectedEOF,
    FileWrite,
    Gl,
    InvalidOperation,
    InvalidValue,
    NotFound,
    OutOfMemory,
    TranscodeFailed,
    UnknownFileFormat,
    UnsupportedTexturetype,
    UnsupportedFeature,
    LibraryNotLinked,
    DecompressLength,
    DecompressChecksum,
};

pub const ClassId = enum(u32) {
    texture1 = 1,
    texture2 = 2,
};

pub const SupercmpScheme = enum(u32) {
    none,
    basis_lz,
    zstd,
    zlib,
};

pub const PackUastc = packed struct(u32) {
    pub const Level = enum(u3) {
        fastest = 0,
        faster = 1,
        default = 2,
        slower = 3,
        veryslow = 4,
    };
    level: Level = .default,
    favor_uastc_error: bool = false,
    favor_bc7_error: bool = false,
    _pad: bool = false,
    etc1_faster_hints: bool = false,
    etc1_fastest_hints: bool = false,
    _etc1_disable_flip_and_individual: bool = false,
    _pad2: u23 = 0,
};

pub const TranscodeFormat = enum(u32) {
    // Compressed formats
    // ETC1-2
    etc1_rgb = 0,
    etc2_rgba = 1,
    // BC1-5, BC7 (desktop, some mobile devices)
    bc1_rgb = 2,
    bc3_rgba = 3,
    bc4_r = 4,
    bc5_rg = 5,
    bc7_rgba = 6,
    // PVRTC1 4bpp (mobile, PowerVR devices)
    pvrtc1_4_rgb = 8,
    pvrtc1_4_rgba = 9,
    // ASTC (mobile, Intel devices, hopefully all desktop GPU's one day)
    astc_4x4_rgba = 10,
    // ATC and FXT1 formats are not supported by KTX2 as there
    // are no equivalent VkFormats.
    pvrtc2_4_rgb = 18,
    pvrtc2_4_rgba = 19,
    etc2_eac_r11 = 20,
    etc2_eac_rg11 = 21,
    // Uncompressed (raw pixel) formats
    rgba32 = 13,
    rgb565 = 14,
    bgr565 = 15,
    rgba4444 = 16,
    // Values for automatic selection of RGB or RGBA depending if alpha
    // present.
    etc = 22,
    bc1_or_3 = 23,
    noselection = 0x7fffffff,
};

pub const TranscodeFlags = enum(u32) {
    pvrtc_decode_to_next_pow2 = 2,
    transcode_alpha_data_to_opaque_formats = 4,
    high_quality = 32,
    _,
};

const FILE = opaque {};
pub const Mem = opaque {};

pub const PFNKTEXDESTROY = ?*const fn (This: *Texture) callconv(.c) void;
pub const PFNKTEXGETIMAGEOFFSET = ?*const fn (This: *Texture, level: u32, layer: u32, faceSlice: u32, pOffset: [*c]u64) callconv(.c) ErrorEnum;
pub const PFNKTEXGETDATASIZEUNCOMPRESSED = ?*const fn (This: *Texture) callconv(.c) u64;
pub const PFNKTEXGETIMAGESIZE = ?*const fn (This: *Texture, level: u32) callconv(.c) u64;
pub const PFNKTEXGETLEVELSIZE = ?*const fn (This: *Texture, level: u32) callconv(.c) u64;
pub const PFNKTXITERCB = ?*const fn (miplevel: c_int, face: c_int, width: c_int, height: c_int, depth: c_int, faceLodSize: u64, pixels: ?*anyopaque, userdata: ?*anyopaque) callconv(.c) ErrorEnum;
pub const PFNKTEXITERATELEVELS = ?*const fn (This: *Texture, iterCb: PFNKTXITERCB, userdata: ?*anyopaque) callconv(.c) ErrorEnum;
pub const PFNKTEXITERATELOADLEVELFACES = ?*const fn (This: *Texture, iterCb: PFNKTXITERCB, userdata: ?*anyopaque) callconv(.c) ErrorEnum;
pub const PFNKTEXNEEDSTRANSCODING = ?*const fn (This: *Texture) callconv(.c) bool;
pub const PFNKTEXLOADIMAGEDATA = ?*const fn (This: *Texture, pBuffer: [*c]u8, bufSize: u64) callconv(.c) ErrorEnum;
pub const PFNKTEXSETIMAGEFROMMEMORY = ?*const fn (This: *Texture, level: u32, layer: u32, faceSlice: u32, src: [*c]const u8, srcSize: u64) callconv(.c) ErrorEnum;
pub const PFNKTEXSETIMAGEFROMSTDIOSTREAM = ?*const fn (This: *Texture, level: u32, layer: u32, faceSlice: u32, src: ?*FILE, srcSize: u64) callconv(.c) ErrorEnum;
pub const PFNKTEXWRITETOSTDIOSTREAM = ?*const fn (This: *Texture, dstsstr: ?*FILE) callconv(.c) ErrorEnum;
pub const PFNKTEXWRITETONAMEDFILE = ?*const fn (This: *Texture, dstname: [*c]const u8) callconv(.c) ErrorEnum;
pub const PFNKTEXWRITETOMEMORY = ?*const fn (This: *Texture, bytes: [*c][*c]u8, size: [*c]u64) callconv(.c) ErrorEnum;
pub const PFNKTEXWRITETOSTREAM = ?*const fn (This: *Texture, dststr: [*c]Stream) callconv(.c) ErrorEnum;

pub const Stream = extern struct {
    pub const readPFN = ?*const fn (str: *Stream, dst: ?*anyopaque, count: u64) callconv(.c) ErrorEnum;
    pub const skipPFN = ?*const fn (str: *Stream, count: u64) callconv(.c) ErrorEnum;
    pub const writePFN = ?*const fn (str: *Stream, src: ?*const anyopaque, size: u64, count: u64) callconv(.c) ErrorEnum;
    pub const getposPFN = ?*const fn (str: *Stream, offset: ?*i64) callconv(.c) ErrorEnum;
    pub const setposPFN = ?*const fn (str: *Stream, offset: i64) callconv(.c) ErrorEnum;
    pub const getsizePFN = ?*const fn (str: *Stream, size: [*c]u64) callconv(.c) ErrorEnum;
    pub const destructPFN = ?*const fn (str: *Stream) callconv(.c) void;
    pub const Type = enum(u32) { file = 1, memory = 2, custom = 3 };
    pub const Data = extern union {
        pub const Custom = extern struct { address: ?*anyopaque, allocatorAddress: ?*anyopaque, size: u64 };
        file: *FILE,
        mem: *Mem,
        custom_ptr: Custom,
    };
    read: readPFN = null,
    skip: skipPFN = null,
    write: writePFN = null,
    getpos: getposPFN = null,
    setpos: setposPFN = null,
    getsize: getsizePFN = null,
    destruct: destructPFN = null,
    type: Type,
    data: Data,
    readpos: i64 = 0,
    closeOnDestruct: bool = false,
};

pub const TextureVtbl = extern struct {
    Destroy: PFNKTEXDESTROY = null,
    GetImageOffset: PFNKTEXGETIMAGEOFFSET = null,
    GetDataSizeUncompressed: PFNKTEXGETDATASIZEUNCOMPRESSED = null,
    GetImageSize: PFNKTEXGETIMAGESIZE = null,
    GetLevelSize: PFNKTEXGETLEVELSIZE = null,
    IterateLevels: PFNKTEXITERATELEVELS = null,
    IterateLoadLevelFaces: PFNKTEXITERATELOADLEVELFACES = null,
    NeedsTranscoding: PFNKTEXNEEDSTRANSCODING = null,
    LoadImageData: PFNKTEXLOADIMAGEDATA = null,
    SetImageFromMemory: PFNKTEXSETIMAGEFROMMEMORY = null,
    SetImageFromStdioStream: PFNKTEXSETIMAGEFROMSTDIOSTREAM = null,
    WriteToStdioStream: PFNKTEXWRITETOSTDIOSTREAM = null,
    WriteToNamedFile: PFNKTEXWRITETONAMEDFILE = null,
    WriteToMemory: PFNKTEXWRITETOMEMORY = null,
    WriteToStream: PFNKTEXWRITETOSTREAM = null,
};
pub const OrientationX = enum(u32) { left = 'l', right = 'r' };
pub const OrientationY = enum(u32) { up = 'u', down = 'd' };
pub const OrientationZ = enum(u32) { in = 'i', out = 'o' };
pub const Orientation = extern struct {
    x: OrientationX,
    y: OrientationY,
    z: OrientationZ,
};

pub const BasisParams = extern struct {
    structSize: u32 = @sizeOf(BasisParams),
    uastc: bool = false,
    verbose: bool = false,
    noSSE: bool = false,
    threadCount: u32 = 0,
    compressionLevel: u32 = 2,
    qualityLevel: u32 = 0,
    maxEndpoints: u32 = 0,
    endpointRDOThreshold: f32 = 0.0,
    maxSelectors: u32 = 0,
    selectorRDOThreshold: f32 = 0.0,
    inputSwizzle: [4]u8 = @splat(0),
    normalMap: bool = false,
    separateRGToRGB_A: bool = false,
    preSwizzle: bool = false,
    noEndpointRDO: bool = false,
    noSelectorRDO: bool = false,
    uastcFlags: PackUastc = .{},
    uastcRDO: bool = false,
    uastcRDOQualityScalar: f32 = 0.0,
    uastcRDODictSize: u32 = 0,
    uastcRDOMaxSmoothBlockErrorScale: f32 = 0.0,
    uastcRDOMaxSmoothBlockStdDev: f32 = 0.0,
    uastcRDODontFavorSimplerModes: bool = false,
    uastcRDONoMultithreading: bool = false,
};

pub const TextureVvbl = opaque {};
pub const TextureProtected = opaque {};
pub const KVListEntry = opaque {};
pub const HashList = *KVListEntry;
pub const Texture = extern struct {
    pub const CreateFlags = packed struct(u32) {
        load_image_data_bit: bool = false,
        raw_kvdata_bit: bool = false,
        skip_kvdata_bit: bool = false,
        check_gltf_basisu_bit: bool = false,
        _padding: u28 = 0,
    };
    pub const CreateStorage = enum(u32) {
        no_storage,
        alloc_storage,
    };
    pub const CreateInfo = extern struct {
        glInternalformat: u32 = 0,
        vkFormat: u32,
        pDfd: ?[*]u32 = null,
        baseWidth: u32,
        baseHeight: u32,
        baseDepth: u32,
        numDimensions: u32,
        numLevels: u32,
        numLayers: u32,
        numFaces: u32,
        isArray: bool,
        generateMipmaps: bool,
    };

    classId: ClassId,
    vtbl: *TextureVtbl,
    vvtbl: *TextureVvbl,
    _protected: *TextureProtected,
    isArray: bool,
    isCubemap: bool,
    isCompressed: bool,
    generateMipmaps: bool,
    baseWidth: u32,
    baseHeight: u32,
    baseDepth: u32,
    numDimensions: u32,
    numLevels: u32,
    numLayers: u32,
    numFaces: u32,
    orientation: Orientation,
    kvDataHead: HashList,
    kvDataLen: u32,
    kvData: [*]u8,
    dataSize: u64,
    pData: [*]u8,
    //tex 2 stuff
    vkFormat: u32,
    pDfd: *u32,
    supercompressionScheme: SupercmpScheme,
    isVideo: bool,
    duration: u32,
    timescale: u32,
    loopcount: u32,
    _private: *opaque {},

    pub fn create(ci: *const CreateInfo, storage_allocation: CreateStorage) !*Texture {
        var tex: *Texture = undefined;
        try makeError(Error, ktxTexture2_Create(ci, storage_allocation, &tex));
        return tex;
    }

    pub fn fromNamedFile(filename: [*:0]const u8, flags: CreateFlags) Error!*Texture {
        var tex: *Texture = undefined;
        try makeError(Error, ktxTexture_CreateFromNamedFile(filename, flags, &tex));
        return tex;
    }

    pub fn fromMemory(memory: []const u8, flags: CreateFlags) Error!*Texture {
        var tex: *Texture = undefined;
        try makeError(Error, ktxTexture2_CreateFromMemory(memory.ptr, memory.len, flags, &tex));
        return tex;
    }

    pub fn setImageFromMemory(texture: *Texture, level: u32, layer: u32, faceSlice: u32, src: []const u8) !void {
        return makeError(Error, texture.vtbl.SetImageFromMemory.?(texture, level, layer, faceSlice, src.ptr, src.len));
    }

    pub fn getVkFormat(this: *Texture) u32 {
        return ktxTexture_GetVkFormat(this);
    }

    pub fn getImageOffset(this: *Texture, level: u32, layer: u32, faceslice: u32) Error!u64 {
        var offset: u64 = 0;
        try makeError(Error, this.vtbl.GetImageOffset.?(this, level, layer, faceslice, &offset));
        return offset;
    }

    pub fn writeToMemory(this: *Texture) Error![]const u8 {
        var slice: []u8 = undefined;
        try makeError(Error, this.vtbl.WriteToMemory.?(this, @ptrCast(&slice.ptr), &slice.len));
        return slice;
    }

    pub fn compressBasisEx(this: *Texture, params: *BasisParams) !void {
        return makeError(Error, ktxTexture2_CompressBasisEx(this, params));
    }

    pub fn transcodeBasis(this: *Texture, fmt: TranscodeFormat, flags: TranscodeFlags) !void {
        return makeError(Error, ktxTexture2_TranscodeBasis(this, fmt, flags));
    }

    pub fn deflateZstd(this: *Texture, level: u32) !void {
        return makeError(Error, ktxTexture2_DeflateZstd(this, level));
    }

    pub fn destroy(this: *Texture) void {
        this.vtbl.Destroy.?(this);
    }
};

extern fn ktxTexture_CreateFromNamedFile(filename: [*:0]const u8, createFlags: Texture.CreateFlags, newTex: **Texture) ErrorEnum;
extern fn ktxTexture2_CreateFromMemory(bytes: [*]const u8, size: usize, createFlags: Texture.CreateFlags, newTex: **Texture) ErrorEnum;
extern fn ktxTexture_GetVkFormat(texture: *Texture) u32;
extern fn ktxTexture2_Create(ci: *const Texture.CreateInfo, storageAllocation: Texture.CreateStorage, newTex: **Texture) ErrorEnum;

extern fn ktxTexture2_CompressBasisEx(this: *Texture, params: *BasisParams) ErrorEnum;
extern fn ktxTexture2_TranscodeBasis(this: *Texture, fmt: TranscodeFormat, transcodeFlags: TranscodeFlags) ErrorEnum;
extern fn ktxTexture2_DeflateZstd(this: *Texture, level: u32) ErrorEnum;
