const h = @import("zkf.zig");
const vk = @import("vk");
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
    // vkFormat: vk.Format,
    // pDfd: *u32,
    // supercompressionScheme: SupercmpScheme,
    // isVideo: bool,
    // duration: u32,
    // timescale: u32,
    // loopcount: u32,
    // _private: *opaque {},

    pub fn fromNamedFile(filename: [*:0]const u8, flags: CreateFlags) Error!*Texture {
        var tex: *Texture = undefined;
        try h.makeError(Error, ktxTexture_CreateFromNamedFile(filename, flags, &tex));
        return tex;
    }
    pub fn getVkFormat(this: *Texture) vk.Format {
        return ktxTexture_GetVkFormat(this);
    }
    pub fn getImageOffset(this: *Texture, level: u32, layer: u32, faceslice: u32) Error!u64 {
        var offset: u64 = 0;
        try h.makeError(Error, this.vtbl.GetImageOffset.?(this, level, layer, faceslice, &offset));
        return offset;
    }
    pub fn destroy(this: *Texture) void {
        this.vtbl.Destroy.?(this);
    }
};

extern fn ktxTexture_CreateFromNamedFile(filename: [*:0]const u8, createFlags: Texture.CreateFlags, newTex: **Texture) ErrorEnum;
extern fn ktxTexture_GetVkFormat(texture: *Texture) vk.Format;
