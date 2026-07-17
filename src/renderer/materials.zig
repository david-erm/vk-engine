const std = @import("std");

const MaterialShaders = enum(u16) {
    pbr,
    skybox,
    light,
};
const MaterialShaderPaths: std.EnumArray(MaterialShaders, []const u8) = .init(.{
    .pbr = "src/shaders/visbuffer/resolve.slang",
    .skybox = "src/shaders/skybox.slang",
    .light = "src/shaders/light.slang",
});

const material_num = @typeInfo(MaterialShaders).@"enum".field_names.len;
