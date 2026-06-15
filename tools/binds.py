from vulkan_object import get_vulkan_object
import re
import argparse

enabled = []
outfile = None

def main():
    global outfile
    parser  = argparse.ArgumentParser()
    parser.add_argument("--version", type=str, help="Vulkan version")
    parser.add_argument("--instance_extensions", nargs='*', type=str, help="Instance Extensions to generate bindings for")
    parser.add_argument("--device_extensions", nargs='*', type=str, help="Device extensions to generate bindings for")
    parser.add_argument("--file", required=True, type=str, help="Output file path")

    args = parser.parse_args()
    if args.version:
        major, minor = args.version.split('.')
        assert (major == '1')
        for i in range(0, int(minor) + 1):
            enabled.append(f"VK_VERSION_{major}_{i}")
    if args.instance_extensions:
        enabled.extend(args.instance_extensions)
    if args.device_extensions:
        enabled.extend(args.device_extensions)

    outfile = open(args.file, "w")


if __name__ == "__main__":
    main()


vk = get_vulkan_object()
global_cmds = ['vkEnumerateInstanceVersion', 'vkEnumerateInstanceExtensionProperties', 'vkEnumerateInstanceLayerProperties', 'vkCreateInstance']
zig_keywords = ['and', 'or', 'inline', 'opaque', 'error']


out = ""
# namespaces
table = ""
table_ns = "table"
glob = ""
global_ns = "global"
instance = ""
instance_ns = "instance"
device = ""
device_ns = "device"

handle_switch = ""


pfnn = ""

# constants get mapped here
vals = {}
vals[None] = "wtf"
# base type conversion
types = {}
types["void"] = "void"
types["char"] = "u8"
types["uint8_t"] = "u8"
types["uint16_t"] = "u16"
types["uint32_t"] = "u32"
types["uint64_t"] = "u64"
types["size_t"] = "u64"
types["int32_t"] = "i32"
types["int"] = "i32"
types["int64_t"] = "i64"
types["float"] = "f32"
types["double"] = "f64"
types["void*"] = "?*anyopaque"

# vulkan stuff
types["VkBool32"] = "Bool"
types["VkSampleMask"] = "u32"
types["VkDeviceSize"] = "DeviceSize"
types["VkDeviceAddress"] = "DeviceAddress"

# complete random stuff
types["VkRemoteAddressNV"] = "?*anyopaque"

pascal_to_words = re.compile(r"[A-Z][a-z]+|[A-Z]+(?![a-z])|[0-9]+")

def check_alias_enabled(requirements):
    if requirements == {}:
        return True
    else:
        exists = any(key in requirements for key in enabled)
        return exists

def check_enabled(thing):
    names = []
    if thing.definingRequirements == {}:
        names.append(thing.name)
    for macro in enabled:
        if macro in thing.definingRequirements:
            if thing.definingRequirements[macro] is None:
                names.append(thing.name)
            elif thing.definingRequirements[macro] in enabled:
                names.append(thing.name)

    if hasattr(thing, "aliases"):
        for alias in thing.aliases:
            requirements = None
            if alias in vk.aliasFlagRequirements:
                requirements = vk.aliasFlagRequirements[alias]
            elif alias in vk.aliasFieldRequirements:
                requirements = vk.aliasFieldRequirements[alias]
            elif alias in vk.aliasTypeRequirements:
                requirements = vk.aliasTypeRequirements[alias]
            if requirements and check_alias_enabled(requirements):
                names.append(alias)

    return names


def make_pascal(name, words):
    packed = re.split("_", name)
    new = ""
    for n in packed[1:]:
        cap = n.capitalize()
        if cap in words:
            words.remove(cap)
            continue
        elif n in words:
            words.remove(n)
            continue
        elif n in vk.vendorTags:
            new += n
        else:
            new += cap
    if new[0].isdigit():
        new = '@"' + new + '"'
    return new


def make_snake(name, words):
    packed = re.split("_", name)
    new = ""
    first = True
    for n in packed[1:]:
        cap = n.capitalize()
        if cap in words:
            words.remove(cap)
            continue
        elif n in words:
            words.remove(n)
            continue
        elif n in vk.vendorTags:
            new += n
        elif cap == "Bit":
            continue
        else:
            if not first:
                new += "_"
            new += cap.lower()
        first = False
    if new[0].isdigit():
        new = '@"' + new + '"'
    elif new in zig_keywords:
        new = '@"' + new + '"'
    return new


def pascal_to_snake(name):
    words = re.findall(pascal_to_words, name)
    out = ""
    first = True
    for w in words:
        if w in vk.vendorTags:
            out += w
            continue
        elif not first:
            out += "_"
        out += w.lower()
        first = False

    return out


def zig_flag(flag):
    global out
    if flag.name in types:
        return
    names = check_enabled(flag)
    if names == []:
        return

    name = names[0][2:]
    types[flag.name] = name
    for alias in names[1:]:
        types[alias] = alias[2:]
        out += f'pub const {alias[2:]} = {name}; //alias\n'

    if flag.bitmaskName:
        bitmask = vk.bitmasks[flag.bitmaskName]
        zig_bitmask(bitmask)
    else:
        out += f"pub const {name} = u32; //unused flag type\n"


def zig_bitmask(bitmask):
    global out
    if bitmask.name in types:
        return
    names = check_enabled(bitmask)
    if names == []:
        return

    newname = names[0].replace("Bit", "")[2:]
    types[bitmask.name] = newname
    for alias in names[1:]:
        flag = alias.replace("Bit", "")
        types[alias] = flag[2:]

    out += f"pub const {newname} = packed struct(u{bitmask.bitWidth}) {{\n"
    words = re.findall(pascal_to_words, names[0][2:])
    current_bit = 0
    padding_num = 0
    fields = ""
    for bit in sorted(bitmask.flags, key=lambda x: (x.bitpos is None, x.bitpos)):
        names = check_enabled(bit)
        if names == []:
            continue
        name = names[0]
        if bit.bitpos is None:
            if bit.zero:
                fields = f"\tpub const {make_snake(name, words.copy())}: @This() = .{{}};\n" + fields
            if bit.multiBit:
                # TODO: not bitcast the int
                fields = f"\tpub const {make_snake(name, words.copy())}: @This() = @bitCast({bit.value});\n" + fields
            continue

        if bit.bitpos != current_bit:
            fields += f"\t_padding{padding_num}: u{bit.bitpos - current_bit} = 0,\n"
            current_bit += bit.bitpos - current_bit
            padding_num += 1
        fields += "\t" + make_snake(name, words.copy()) + ": bool = false,\n"
        current_bit += 1
    if current_bit < bitmask.bitWidth:
        fields += f"\t_padding{padding_num}: u{bitmask.bitWidth - current_bit} = 0,\n"
    out += fields
    out += "};\n"


def zig_enum(enum):
    global out
    if enum.name in types:
        return
    names = check_enabled(enum)
    if names == []:
        return
    name = names[0]
    for alias in names[1:]:
        out += f'pub const {alias[2:]} = {name};\n'
        types[alias] = alias[2:]

    wrds = re.findall(pascal_to_words, name)
    types[name] = name[2:]

    if enum.name == "VkResult":
        out += f'pub const {enum.name[2:]}Err = error {{\n'
        for field in enum.fields:
            fields = check_enabled(field)
            if fields == [] or field.value == 0:
                continue
            newname = make_snake(fields[0], wrds.copy())
            out += "\t" + newname + ",\n"
        out += "};\n"

    out += f"pub const {enum.name[2:]} = enum(i{enum.bitWidth}) {{\n"
    contents = ""
    for field in enum.fields:
        fields = check_enabled(field)
        if fields == []:
            continue
        newname = make_snake(fields[0], wrds.copy())
        vals[fields[0]] = newname
        for alias in fields[1:]:
            contents = f"\tpub const {make_snake(alias, wrds.copy())}: @This() = .{newname}; //alias\n"
        contents += "\t" + newname + f" = {field.value},\n"
    out += contents
    out += "};\n"


def zig_pfn(pfn):
    if pfn.name in types:
        return
    if pfn.requires and pfn.requires not in types:
        return

    name = pfn.name[6:]

    buffer = ""
    buffer += "\tpub const " + name + " = ?*const fn ("
    types[pfn.name] = "pfn." + name
    first = True
    for param in pfn.params:
        if param.type not in types:
            return
        if not first:
            buffer += ', '
        buffer += param.name + ": "
        if "void*" in param.fullType:
            buffer += "?*anyopaque"
            first = False
            continue
        elif "const char*" in param.fullType:
            buffer += "[*:0]const u8"
            first = False
            continue
        if "*" in param.fullType:
            buffer += "*"
        buffer += f"{types[param.type]}"
        first = False
    buffer += ") callconv(.c) " + types[pfn.returnType] + ";\n"
    global pfnn
    pfnn += buffer


def zig_handle(handle):
    global out
    global handle_switch
    if handle.name in types:
        return
    names = check_enabled(handle)
    if names == []:
        return

    newname = names[0][2:]
    types[handle.name] = newname
    for alias in names[1:]:
        out += f'pub const {alias} = {newname};\n'
        types[alias] = alias[2:]

    out += f"const {newname}_t = opaque{{}};\n"
    out  += f"pub const {newname} = *{newname}_t;\n"

    handle_switch += f"\t\t{newname} => .{pascal_to_snake(newname)},\n"


def parse_type(type):
    if type.type not in types:
        if type.type in vk.enums:
            zig_enum(vk.enums[type.type])

    ret = ""

    if type.pointer:
        if type.name.startswith("pp"):
            ret += "?[*]const "
        if type.optional or type.optionalPointer:
            ret += "?"
        if type.nullTerminated:
            ret += "[*:0]"
        elif type.length:
            ret += "[*]"
        else:
            ret += "*"
        if type.const:
            ret += "const "
    elif type.type in vk.handles and type.optional:
        ret += "?"

    elif type.fixedSizeArray:
        length = type.fixedSizeArray[0]
        if length in vk.constants:
            ret += f"[{vals[length]}]"
        else:
            if "," in length:
                nums = re.split(",", length)
                for num in nums:
                    ret += f"[{num}]"
            else:
                ret += f"[{length}]"

    if type.pointer and type.type == "void":
        if type.length:
            ret += "u8"
        else:
            ret += "anyopaque"
    else:
        ret += types[type.type]
    return ret


def get_default(type):
    ret = ""

    if (type.pointer or type.type in vk.handles) and type.optional:
        ret += " = null"
    elif type.pointer or type.type in vk.handles:
        ret += " = undefined"
    elif type.type == "VkBool32":
        ret += " = .False"
    elif type.type in vk.enums:
        for field in vk.enums[type.type].fields:
            if field.value == 0:
                ret += f" = .{vals[field.name]}"

    elif type.type in vk.flags and vk.flags[type.type].bitmaskName or type.type in vk.structs:
        if type.fixedSizeArray:
            ret += " = @splat(.{})"
        else:
            ret += " = .{}"
    elif "int" in type.type or "float" in type.type or "char" in type.type:
        if type.length or type.fixedSizeArray:
            ret += " = @splat(0)"
        else:
            ret += " = 0"
    else:
        ret += f" = std.mem.zeroes({types[type.type]})"

    return ret


def handle_member(mem, st):
    if mem.type == "VkStructureType":
        return ""

    ret = "\t"

    if mem.type in vk.structs:
        zig_struct(vk.structs[mem.type])

    ret += mem.name + ": "

    ret += parse_type(mem)
    if mem.name.startswith("pp"):
        ret += " = null"
    elif not (mem.type in vk.structs and vk.structs[mem.type].union or st.union):
        ret += get_default(mem)

    ret += ",\n"
    return ret


def zig_struct(st):
    global out
    if st.name in types or st.name == "VkStructureType":
        return
    names = check_enabled(st)
    if names == []:
        return

    ret = ""

    name = names[0][2:]
    types[st.name] = name
    for alias in names[1:]:
        ret += f'pub const {alias[2:]} = {name}; //alias\n'
        types[alias] = alias[2:]

    ret += "pub const " + name + " = extern "
    if st.union:
        ret += "union {\n"
    else:
        ret += "struct {\n"

    if st.sType:
        val = 0
        for field in vk.enums["VkStructureType"].fields:
            if field.name == st.sType:
                val = field.value
        ret += f'\tsType: i32 = {val},\n'
        assert st.members[0].type == "VkStructureType"

    for member in st.members:
        ret += handle_member(member, st)

    ret += "};\n"

    out += ret


def zig_const(const):
    global out
    name = make_pascal(const.name, "VK")
    vals[const.name] = name
    out += f"pub const {name} = {const.value};\n"


def zig_cmd(cmd):
    global out
    global instance
    global device
    global glob
    global pfnn
    if cmd.name in types:
        return
    if not check_enabled(cmd):
        return

    name = cmd.name[2:]
    name = name[:1].lower() + name[1:]
    types[cmd.name] = name
    if cmd.alias:
        types[cmd.alias] = name

    cmd.alias

    params = ''
    first = True
    for param in cmd.params:
        if not first:
            params += ', '
        if "type" == param.name:
            params += "Type: "
        else:
            params += f"{param.name}: "
        params += f"{parse_type(param)}"
        first = False

    pfnn += f"\tpub const {cmd.name} = *const fn({params}) callconv(.c) {types[cmd.returnType]};\n"

    prefix = ""
    if cmd.name in global_cmds:
        glob += f'\t\tpub var {cmd.name}: pfn.{cmd.name} = undefined;\n'
        prefix = global_ns
    elif cmd.instance:
        instance += f'\t\tpub var {cmd.name}: pfn.{cmd.name} = undefined;\n'
        prefix = instance_ns
    else:
        device += f'\t\tpub var {cmd.name}: pfn.{cmd.name} = undefined;\n'
        prefix = device_ns

    if cmd.returnType == "VkResult":
        out += f'pub fn {name}({params}) ResultErr!void {{\n\treturn makeError(ResultErr, {table_ns}.{prefix}.{cmd.name}('
    else:
        out += f"pub fn {name}({params}) {types[cmd.returnType]} {{\n\treturn {table_ns}.{prefix}.{cmd.name}("
    first = True
    for param in cmd.params:
        if "type" == param.name:
            paramname = "Type"
        else:
            paramname = param.name
        if first:
            out += f"{paramname}"
            first = False
        else:
            out += f", {paramname}"

    if cmd.returnType == "VkResult":
        out += ")"
    out += ");\n}\n"


# all the buffers are filled
for enum in vk.enums.values():
    zig_enum(enum)

for flag in vk.flags.values():
    zig_flag(flag)

for handle in vk.handles.values():
    zig_handle(handle)

for const in vk.constants.values():
    zig_const(const)

# need to fix these, the types all are wrong
for pfn in vk.funcPointers.values():
    if pfn.requires:
        if pfn.requires in vk.structs:
            zig_struct(vk.structs[pfn.requires])
        elif pfn.requires in vk.handles:
            zig_handle(vk.handles[pfn.requires])
        else:
            continue
    zig_pfn(pfn)

for st in vk.structs.values():
    zig_struct(st)

for cmd in vk.commands.values():
    zig_cmd(cmd)


# start genning binds
header = """const std = @import("std");
pub fn makeApiVersion(variant: u32, major: u32, minor: u32, patch: u32) u32 { return variant << 29 | major << 22 | minor << 12 | patch;}
pub const Bool = enum(u32) { False, True };
pub const DeviceSize = u64;
pub const DeviceAddress = enum(u64) { _ };
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
pub fn load(proc: pfn.vkGetInstanceProcAddr) void {
    inline for (@typeInfo(table.global).@"struct".decl_names) |field| {
        @field(table.global, field) = @ptrCast(proc(null, field.ptr));
        table.instance.vkGetInstanceProcAddr = proc;
    }
}
pub fn loadInstance(instance: Instance) void {
    inline for (@typeInfo(table.instance).@"struct".decl_names) |field| {
        @field(table.instance, field) = @ptrCast(table.instance.vkGetInstanceProcAddr(instance, field.ptr));
        table.device.vkGetDeviceProcAddr = @ptrCast(table.instance.vkGetInstanceProcAddr(instance, "vkGetDeviceProcAddr"));
    }
}
pub fn loadDevice(device: Device) void {
    inline for (@typeInfo(table.device).@"struct".decl_names) |field| {
        @field(table.device, field) = @ptrCast(table.device.vkGetDeviceProcAddr(device, field.ptr));
    }
}
"""
if "VK_EXT_debug_utils" in enabled:
    header += f"""
    pub fn nameHandle(device: Device, handle: anytype, name: [*:0]const u8) !void {{
        const handle_type: ObjectType = switch (@TypeOf(handle)) {{
    {handle_switch}
            else => @compileError("Not a VK Handle"),
        }};
        const ci: DebugUtilsObjectNameInfoEXT = .{{
            .objectHandle = @intFromPtr(handle),
            .pObjectName = name,
            .objectType = handle_type,
        }};
        try setDebugUtilsObjectNameEXT(device, &ci);
    }}
    """

print(header, file=outfile)
print(out, file=outfile)
print(f'pub const {table_ns} = struct {{', file=outfile)
print(f'\tpub const {global_ns} = struct {{{glob}\t}};', file=outfile)
print(f'\tpub const {instance_ns} = struct {{{instance}\t}};', file=outfile)
print(f'\tpub const {device_ns} = struct {{{device}\t}};', file=outfile)
print('};', file=outfile)
print('pub const pfn = struct {\n ' + pfnn + '};', file=outfile)
