const std = @import("std");
pub fn makeApiVersion(variant: u32, major: u32, minor: u32, patch: u32) u32 {
    return variant << 29 | major << 22 | minor << 12 | patch;
}
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
    inline for (@typeInfo(table.global).@"struct".decls) |field| {
        @field(table.global, field.name) = @ptrCast(proc(null, field.name.ptr));
        table.instance.vkGetInstanceProcAddr = proc;
    }
}
pub fn loadInstance(instance: Instance) void {
    inline for (@typeInfo(table.instance).@"struct".decls) |field| {
        @field(table.instance, field.name) = @ptrCast(table.instance.vkGetInstanceProcAddr(instance, field.name.ptr));
        table.device.vkGetDeviceProcAddr = @ptrCast(table.instance.vkGetInstanceProcAddr(instance, "vkGetDeviceProcAddr"));
    }
}
pub fn loadDevice(device: Device) void {
    inline for (@typeInfo(table.device).@"struct".decls) |field| {
        @field(table.device, field.name) = @ptrCast(table.device.vkGetDeviceProcAddr(device, field.name.ptr));
    }
}
pub fn nameHandle(device: Device, handle: anytype, name: [*:0]const u8) !void {
    const handle_type: ObjectType = switch (@TypeOf(handle)) {
        Instance => .instance,
        PhysicalDevice => .physical_device,
        Device => .device,
        Queue => .queue,
        Semaphore => .semaphore,
        CommandBuffer => .command_buffer,
        Fence => .fence,
        DeviceMemory => .device_memory,
        Buffer => .buffer,
        Image => .image,
        QueryPool => .query_pool,
        ImageView => .image_view,
        CommandPool => .command_pool,
        RenderPass => .render_pass,
        Framebuffer => .framebuffer,
        Event => .event,
        BufferView => .buffer_view,
        ShaderModule => .shader_module,
        PipelineCache => .pipeline_cache,
        Pipeline => .pipeline,
        PipelineLayout => .pipeline_layout,
        DescriptorSetLayout => .descriptor_set_layout,
        Sampler => .sampler,
        DescriptorSet => .descriptor_set,
        DescriptorPool => .descriptor_pool,
        DescriptorUpdateTemplate => .descriptor_update_template,
        SamplerYcbcrConversion => .sampler_ycbcr_conversion,
        PrivateDataSlot => .private_data_slot,
        SurfaceKHR => .surfaceKHR,
        SwapchainKHR => .swapchainKHR,
        DebugUtilsMessengerEXT => .debug_utils_messengerEXT,

        else => @compileError("Not a VK Handle"),
    };
    const ci: DebugUtilsObjectNameInfoEXT = .{
        .objectHandle = @intFromPtr(handle),
        .pObjectName = name,
        .objectType = handle_type,
    };
    try setDebugUtilsObjectNameEXT(device, &ci);
}
pub const ResultErr = error{
    not_ready,
    timeout,
    event_set,
    event_reset,
    incomplete,
    error_out_of_host_memory,
    error_out_of_device_memory,
    error_initialization_failed,
    error_device_lost,
    error_memory_map_failed,
    error_layer_not_present,
    error_extension_not_present,
    error_feature_not_present,
    error_incompatible_driver,
    error_too_many_objects,
    error_format_not_supported,
    error_fragmented_pool,
    error_unknown,
    error_validation_failed,
    error_out_of_pool_memory,
    error_invalid_external_handle,
    error_invalid_opaque_capture_address,
    error_fragmentation,
    pipeline_compile_required,
    error_surface_lostKHR,
    error_native_window_in_useKHR,
    suboptimalKHR,
    error_out_of_dateKHR,
};
pub const Result = enum(i32) {
    success = 0,
    not_ready = 1,
    timeout = 2,
    event_set = 3,
    event_reset = 4,
    incomplete = 5,
    error_out_of_host_memory = -1,
    error_out_of_device_memory = -2,
    error_initialization_failed = -3,
    error_device_lost = -4,
    error_memory_map_failed = -5,
    error_layer_not_present = -6,
    error_extension_not_present = -7,
    error_feature_not_present = -8,
    error_incompatible_driver = -9,
    error_too_many_objects = -10,
    error_format_not_supported = -11,
    error_fragmented_pool = -12,
    error_unknown = -13,
    error_validation_failed = -1000011001,
    error_out_of_pool_memory = -1000069000,
    error_invalid_external_handle = -1000072003,
    error_invalid_opaque_capture_address = -1000257000,
    error_fragmentation = -1000161000,
    pipeline_compile_required = 1000297000,
    error_surface_lostKHR = -1000000000,
    error_native_window_in_useKHR = -1000000001,
    suboptimalKHR = 1000001003,
    error_out_of_dateKHR = -1000001004,
};
pub const StructureType = enum(i32) {
    application_info = 0,
    instance_create_info = 1,
    device_queue_create_info = 2,
    device_create_info = 3,
    submit_info = 4,
    memory_allocate_info = 5,
    mapped_memory_range = 6,
    bind_sparse_info = 7,
    fence_create_info = 8,
    semaphore_create_info = 9,
    event_create_info = 10,
    query_pool_create_info = 11,
    buffer_create_info = 12,
    buffer_view_create_info = 13,
    image_create_info = 14,
    image_view_create_info = 15,
    shader_module_create_info = 16,
    pipeline_cache_create_info = 17,
    pipeline_shader_stage_create_info = 18,
    pipeline_vertex_input_state_create_info = 19,
    pipeline_input_assembly_state_create_info = 20,
    pipeline_tessellation_state_create_info = 21,
    pipeline_viewport_state_create_info = 22,
    pipeline_rasterization_state_create_info = 23,
    pipeline_multisample_state_create_info = 24,
    pipeline_depth_stencil_state_create_info = 25,
    pipeline_color_blend_state_create_info = 26,
    pipeline_dynamic_state_create_info = 27,
    graphics_pipeline_create_info = 28,
    compute_pipeline_create_info = 29,
    pipeline_layout_create_info = 30,
    sampler_create_info = 31,
    descriptor_set_layout_create_info = 32,
    descriptor_pool_create_info = 33,
    descriptor_set_allocate_info = 34,
    write_descriptor_set = 35,
    copy_descriptor_set = 36,
    framebuffer_create_info = 37,
    render_pass_create_info = 38,
    command_pool_create_info = 39,
    command_buffer_allocate_info = 40,
    command_buffer_inheritance_info = 41,
    command_buffer_begin_info = 42,
    render_pass_begin_info = 43,
    buffer_memory_barrier = 44,
    image_memory_barrier = 45,
    memory_barrier = 46,
    loader_instance_create_info = 47,
    loader_device_create_info = 48,
    bind_buffer_memory_info = 1000157000,
    bind_image_memory_info = 1000157001,
    memory_dedicated_requirements = 1000127000,
    memory_dedicated_allocate_info = 1000127001,
    memory_allocate_flags_info = 1000060000,
    device_group_command_buffer_begin_info = 1000060004,
    device_group_submit_info = 1000060005,
    device_group_bind_sparse_info = 1000060006,
    bind_buffer_memory_device_group_info = 1000060013,
    bind_image_memory_device_group_info = 1000060014,
    physical_device_group_properties = 1000070000,
    device_group_device_create_info = 1000070001,
    buffer_memory_requirements_info_2 = 1000146000,
    image_memory_requirements_info_2 = 1000146001,
    image_sparse_memory_requirements_info_2 = 1000146002,
    memory_requirements_2 = 1000146003,
    sparse_image_memory_requirements_2 = 1000146004,
    physical_device_features_2 = 1000059000,
    physical_device_properties_2 = 1000059001,
    format_properties_2 = 1000059002,
    image_format_properties_2 = 1000059003,
    physical_device_image_format_info_2 = 1000059004,
    queue_family_properties_2 = 1000059005,
    physical_device_memory_properties_2 = 1000059006,
    sparse_image_format_properties_2 = 1000059007,
    physical_device_sparse_image_format_info_2 = 1000059008,
    image_view_usage_create_info = 1000117002,
    protected_submit_info = 1000145000,
    physical_device_protected_memory_features = 1000145001,
    physical_device_protected_memory_properties = 1000145002,
    device_queue_info_2 = 1000145003,
    physical_device_external_image_format_info = 1000071000,
    external_image_format_properties = 1000071001,
    physical_device_external_buffer_info = 1000071002,
    external_buffer_properties = 1000071003,
    physical_device_id_properties = 1000071004,
    external_memory_buffer_create_info = 1000072000,
    external_memory_image_create_info = 1000072001,
    export_memory_allocate_info = 1000072002,
    physical_device_external_fence_info = 1000112000,
    external_fence_properties = 1000112001,
    export_fence_create_info = 1000113000,
    export_semaphore_create_info = 1000077000,
    physical_device_external_semaphore_info = 1000076000,
    external_semaphore_properties = 1000076001,
    physical_device_subgroup_properties = 1000094000,
    physical_device_16bit_storage_features = 1000083000,
    physical_device_variable_pointers_features = 1000120000,
    descriptor_update_template_create_info = 1000085000,
    physical_device_maintenance_3_properties = 1000168000,
    descriptor_set_layout_support = 1000168001,
    sampler_ycbcr_conversion_create_info = 1000156000,
    sampler_ycbcr_conversion_info = 1000156001,
    bind_image_plane_memory_info = 1000156002,
    image_plane_memory_requirements_info = 1000156003,
    physical_device_sampler_ycbcr_conversion_features = 1000156004,
    sampler_ycbcr_conversion_image_format_properties = 1000156005,
    device_group_render_pass_begin_info = 1000060003,
    physical_device_point_clipping_properties = 1000117000,
    render_pass_input_attachment_aspect_create_info = 1000117001,
    pipeline_tessellation_domain_origin_state_create_info = 1000117003,
    render_pass_multiview_create_info = 1000053000,
    physical_device_multiview_features = 1000053001,
    physical_device_multiview_properties = 1000053002,
    physical_device_shader_draw_parameters_features = 1000063000,
    physical_device_driver_properties = 1000196000,
    physical_device_vulkan_1_1_features = 49,
    physical_device_vulkan_1_1_properties = 50,
    physical_device_vulkan_1_2_features = 51,
    physical_device_vulkan_1_2_properties = 52,
    image_format_list_create_info = 1000147000,
    physical_device_vulkan_memory_model_features = 1000211000,
    physical_device_host_query_reset_features = 1000261000,
    physical_device_timeline_semaphore_features = 1000207000,
    physical_device_timeline_semaphore_properties = 1000207001,
    semaphore_type_create_info = 1000207002,
    timeline_semaphore_submit_info = 1000207003,
    semaphore_wait_info = 1000207004,
    semaphore_signal_info = 1000207005,
    physical_device_buffer_device_address_features = 1000257000,
    buffer_device_address_info = 1000244001,
    buffer_opaque_capture_address_create_info = 1000257002,
    memory_opaque_capture_address_allocate_info = 1000257003,
    device_memory_opaque_capture_address_info = 1000257004,
    physical_device_8bit_storage_features = 1000177000,
    physical_device_shader_atomic_int64_features = 1000180000,
    physical_device_shader_float16_int8_features = 1000082000,
    physical_device_float_controls_properties = 1000197000,
    descriptor_set_layout_binding_flags_create_info = 1000161000,
    physical_device_descriptor_indexing_features = 1000161001,
    physical_device_descriptor_indexing_properties = 1000161002,
    descriptor_set_variable_descriptor_count_allocate_info = 1000161003,
    descriptor_set_variable_descriptor_count_layout_support = 1000161004,
    physical_device_scalar_block_layout_features = 1000221000,
    physical_device_sampler_filter_minmax_properties = 1000130000,
    sampler_reduction_mode_create_info = 1000130001,
    physical_device_uniform_buffer_standard_layout_features = 1000253000,
    physical_device_shader_subgroup_extended_types_features = 1000175000,
    attachment_description_2 = 1000109000,
    attachment_reference_2 = 1000109001,
    subpass_description_2 = 1000109002,
    subpass_dependency_2 = 1000109003,
    render_pass_create_info_2 = 1000109004,
    subpass_begin_info = 1000109005,
    subpass_end_info = 1000109006,
    physical_device_depth_stencil_resolve_properties = 1000199000,
    subpass_description_depth_stencil_resolve = 1000199001,
    image_stencil_usage_create_info = 1000246000,
    physical_device_imageless_framebuffer_features = 1000108000,
    framebuffer_attachments_create_info = 1000108001,
    framebuffer_attachment_image_info = 1000108002,
    render_pass_attachment_begin_info = 1000108003,
    physical_device_separate_depth_stencil_layouts_features = 1000241000,
    attachment_reference_stencil_layout = 1000241001,
    attachment_description_stencil_layout = 1000241002,
    physical_device_vulkan_1_3_features = 53,
    physical_device_vulkan_1_3_properties = 54,
    physical_device_tool_properties = 1000245000,
    physical_device_private_data_features = 1000295000,
    device_private_data_create_info = 1000295001,
    private_data_slot_create_info = 1000295002,
    memory_barrier_2 = 1000314000,
    buffer_memory_barrier_2 = 1000314001,
    image_memory_barrier_2 = 1000314002,
    dependency_info = 1000314003,
    submit_info_2 = 1000314004,
    semaphore_submit_info = 1000314005,
    command_buffer_submit_info = 1000314006,
    physical_device_synchronization_2_features = 1000314007,
    copy_buffer_info_2 = 1000337000,
    copy_image_info_2 = 1000337001,
    copy_buffer_to_image_info_2 = 1000337002,
    copy_image_to_buffer_info_2 = 1000337003,
    buffer_copy_2 = 1000337006,
    image_copy_2 = 1000337007,
    buffer_image_copy_2 = 1000337009,
    physical_device_texture_compression_astc_hdr_features = 1000066000,
    format_properties_3 = 1000360000,
    physical_device_maintenance_4_features = 1000413000,
    physical_device_maintenance_4_properties = 1000413001,
    device_buffer_memory_requirements = 1000413002,
    device_image_memory_requirements = 1000413003,
    pipeline_creation_feedback_create_info = 1000192000,
    physical_device_shader_terminate_invocation_features = 1000215000,
    physical_device_shader_demote_to_helper_invocation_features = 1000276000,
    physical_device_pipeline_creation_cache_control_features = 1000297000,
    physical_device_zero_initialize_workgroup_memory_features = 1000325000,
    physical_device_image_robustness_features = 1000335000,
    physical_device_subgroup_size_control_properties = 1000225000,
    pipeline_shader_stage_required_subgroup_size_create_info = 1000225001,
    physical_device_subgroup_size_control_features = 1000225002,
    physical_device_inline_uniform_block_features = 1000138000,
    physical_device_inline_uniform_block_properties = 1000138001,
    write_descriptor_set_inline_uniform_block = 1000138002,
    descriptor_pool_inline_uniform_block_create_info = 1000138003,
    physical_device_shader_integer_dot_product_features = 1000280000,
    physical_device_shader_integer_dot_product_properties = 1000280001,
    physical_device_texel_buffer_alignment_properties = 1000281001,
    blit_image_info_2 = 1000337004,
    resolve_image_info_2 = 1000337005,
    image_blit_2 = 1000337008,
    image_resolve_2 = 1000337010,
    rendering_info = 1000044000,
    rendering_attachment_info = 1000044001,
    pipeline_rendering_create_info = 1000044002,
    physical_device_dynamic_rendering_features = 1000044003,
    command_buffer_inheritance_rendering_info = 1000044004,
    swapchain_create_infoKHR = 1000001000,
    present_infoKHR = 1000001001,
    device_group_present_capabilitiesKHR = 1000060007,
    image_swapchain_create_infoKHR = 1000060008,
    bind_image_memory_swapchain_infoKHR = 1000060009,
    acquire_next_image_infoKHR = 1000060010,
    device_group_present_infoKHR = 1000060011,
    device_group_swapchain_create_infoKHR = 1000060012,
    debug_utils_object_name_infoEXT = 1000128000,
    debug_utils_object_tag_infoEXT = 1000128001,
    debug_utils_labelEXT = 1000128002,
    debug_utils_messenger_callback_dataEXT = 1000128003,
    debug_utils_messenger_create_infoEXT = 1000128004,
};
pub const ObjectType = enum(i32) {
    unknown = 0,
    instance = 1,
    physical_device = 2,
    device = 3,
    queue = 4,
    semaphore = 5,
    command_buffer = 6,
    fence = 7,
    device_memory = 8,
    buffer = 9,
    image = 10,
    event = 11,
    query_pool = 12,
    buffer_view = 13,
    image_view = 14,
    shader_module = 15,
    pipeline_cache = 16,
    pipeline_layout = 17,
    render_pass = 18,
    pipeline = 19,
    descriptor_set_layout = 20,
    sampler = 21,
    descriptor_pool = 22,
    descriptor_set = 23,
    framebuffer = 24,
    command_pool = 25,
    descriptor_update_template = 1000085000,
    sampler_ycbcr_conversion = 1000156000,
    private_data_slot = 1000295000,
    surfaceKHR = 1000000000,
    swapchainKHR = 1000001000,
    debug_utils_messengerEXT = 1000128000,
};
pub const VendorId = enum(i32) {
    khronos = 65536,
    VIV = 65537,
    VSI = 65538,
    kazan = 65539,
    codeplay = 65540,
    MESA = 65541,
    pocl = 65542,
    mobileye = 65543,
};
pub const SystemAllocationScope = enum(i32) {
    command = 0,
    object = 1,
    cache = 2,
    device = 3,
    instance = 4,
};
pub const InternalAllocationType = enum(i32) {
    executable = 0,
};
pub const Format = enum(i32) {
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
pub const ImageTiling = enum(i32) {
    optimal = 0,
    linear = 1,
};
pub const ImageType = enum(i32) {
    @"1d" = 0,
    @"2d" = 1,
    @"3d" = 2,
};
pub const PhysicalDeviceType = enum(i32) {
    other = 0,
    integrated_gpu = 1,
    discrete_gpu = 2,
    virtual_gpu = 3,
    cpu = 4,
};
pub const QueryType = enum(i32) {
    occlusion = 0,
    pipeline_statistics = 1,
    timestamp = 2,
};
pub const SharingMode = enum(i32) {
    exclusive = 0,
    concurrent = 1,
};
pub const ImageLayout = enum(i32) {
    undefined = 0,
    general = 1,
    color_attachment_optimal = 2,
    depth_stencil_attachment_optimal = 3,
    depth_stencil_read_only_optimal = 4,
    shader_read_only_optimal = 5,
    transfer_src_optimal = 6,
    transfer_dst_optimal = 7,
    preinitialized = 8,
    depth_read_only_stencil_attachment_optimal = 1000117000,
    depth_attachment_stencil_read_only_optimal = 1000117001,
    depth_attachment_optimal = 1000241000,
    depth_read_only_optimal = 1000241001,
    stencil_attachment_optimal = 1000241002,
    stencil_read_only_optimal = 1000241003,
    read_only_optimal = 1000314000,
    attachment_optimal = 1000314001,
    present_srcKHR = 1000001002,
};
pub const ComponentSwizzle = enum(i32) {
    identity = 0,
    zero = 1,
    one = 2,
    r = 3,
    g = 4,
    b = 5,
    a = 6,
};
pub const ImageViewType = enum(i32) {
    @"1d" = 0,
    @"2d" = 1,
    @"3d" = 2,
    cube = 3,
    @"1d_array" = 4,
    @"2d_array" = 5,
    cube_array = 6,
};
pub const CommandBufferLevel = enum(i32) {
    primary = 0,
    secondary = 1,
};
pub const IndexType = enum(i32) {
    uint16 = 0,
    uint32 = 1,
};
pub const PipelineCacheHeaderVersion = enum(i32) {
    one = 1,
};
pub const BorderColor = enum(i32) {
    float_transparent_black = 0,
    int_transparent_black = 1,
    float_opaque_black = 2,
    int_opaque_black = 3,
    float_opaque_white = 4,
    int_opaque_white = 5,
};
pub const Filter = enum(i32) {
    nearest = 0,
    linear = 1,
};
pub const SamplerAddressMode = enum(i32) {
    repeat = 0,
    mirrored_repeat = 1,
    clamp_to_edge = 2,
    clamp_to_border = 3,
    mirror_clamp_to_edge = 4,
};
pub const CompareOp = enum(i32) {
    never = 0,
    less = 1,
    equal = 2,
    less_or_equal = 3,
    greater = 4,
    not_equal = 5,
    greater_or_equal = 6,
    always = 7,
};
pub const SamplerMipmapMode = enum(i32) {
    nearest = 0,
    linear = 1,
};
pub const DescriptorType = enum(i32) {
    sampler = 0,
    combined_image_sampler = 1,
    sampled_image = 2,
    storage_image = 3,
    uniform_texel_buffer = 4,
    storage_texel_buffer = 5,
    uniform_buffer = 6,
    storage_buffer = 7,
    uniform_buffer_dynamic = 8,
    storage_buffer_dynamic = 9,
    input_attachment = 10,
    inline_uniform_block = 1000138000,
};
pub const PipelineBindPoint = enum(i32) {
    graphics = 0,
    compute = 1,
};
pub const BlendFactor = enum(i32) {
    zero = 0,
    one = 1,
    src_color = 2,
    one_minus_src_color = 3,
    dst_color = 4,
    one_minus_dst_color = 5,
    src_alpha = 6,
    one_minus_src_alpha = 7,
    dst_alpha = 8,
    one_minus_dst_alpha = 9,
    constant_color = 10,
    one_minus_constant_color = 11,
    constant_alpha = 12,
    one_minus_constant_alpha = 13,
    src_alpha_saturate = 14,
    src1_color = 15,
    one_minus_src1_color = 16,
    src1_alpha = 17,
    one_minus_src1_alpha = 18,
};
pub const BlendOp = enum(i32) {
    add = 0,
    subtract = 1,
    reverse_subtract = 2,
    min = 3,
    max = 4,
};
pub const DynamicState = enum(i32) {
    viewport = 0,
    scissor = 1,
    line_width = 2,
    depth_bias = 3,
    blend_constants = 4,
    depth_bounds = 5,
    stencil_compare_mask = 6,
    stencil_write_mask = 7,
    stencil_reference = 8,
    cull_mode = 1000267000,
    front_face = 1000267001,
    primitive_topology = 1000267002,
    viewport_with_count = 1000267003,
    scissor_with_count = 1000267004,
    vertex_input_binding_stride = 1000267005,
    depth_test_enable = 1000267006,
    depth_write_enable = 1000267007,
    depth_compare_op = 1000267008,
    depth_bounds_test_enable = 1000267009,
    stencil_test_enable = 1000267010,
    stencil_op = 1000267011,
    rasterizer_discard_enable = 1000377001,
    depth_bias_enable = 1000377002,
    primitive_restart_enable = 1000377004,
};
pub const FrontFace = enum(i32) {
    counter_clockwise = 0,
    clockwise = 1,
};
pub const LogicOp = enum(i32) {
    clear = 0,
    @"and" = 1,
    and_reverse = 2,
    copy = 3,
    and_inverted = 4,
    no_op = 5,
    xor = 6,
    @"or" = 7,
    nor = 8,
    equivalent = 9,
    invert = 10,
    or_reverse = 11,
    copy_inverted = 12,
    or_inverted = 13,
    nand = 14,
    set = 15,
};
pub const StencilOp = enum(i32) {
    keep = 0,
    zero = 1,
    replace = 2,
    increment_and_clamp = 3,
    decrement_and_clamp = 4,
    invert = 5,
    increment_and_wrap = 6,
    decrement_and_wrap = 7,
};
pub const VertexInputRate = enum(i32) {
    vertex = 0,
    instance = 1,
};
pub const PrimitiveTopology = enum(i32) {
    point_list = 0,
    line_list = 1,
    line_strip = 2,
    triangle_list = 3,
    triangle_strip = 4,
    triangle_fan = 5,
    line_list_with_adjacency = 6,
    line_strip_with_adjacency = 7,
    triangle_list_with_adjacency = 8,
    triangle_strip_with_adjacency = 9,
    patch_list = 10,
};
pub const PolygonMode = enum(i32) {
    fill = 0,
    line = 1,
    point = 2,
};
pub const AttachmentLoadOp = enum(i32) {
    load = 0,
    clear = 1,
    dont_care = 2,
};
pub const AttachmentStoreOp = enum(i32) {
    store = 0,
    dont_care = 1,
    none = 1000301000,
};
pub const SubpassContents = enum(i32) {
    @"inline" = 0,
    secondary_command_buffers = 1,
};
pub const PointClippingBehavior = enum(i32) {
    all_clip_planes = 0,
    user_clip_planes_only = 1,
};
pub const DescriptorUpdateTemplateType = enum(i32) {
    descriptor_set = 0,
};
pub const SamplerYcbcrModelConversion = enum(i32) {
    rgb_identity = 0,
    ycbcr_identity = 1,
    ycbcr_709 = 2,
    ycbcr_601 = 3,
    ycbcr_2020 = 4,
};
pub const SamplerYcbcrRange = enum(i32) {
    itu_full = 0,
    itu_narrow = 1,
};
pub const ChromaLocation = enum(i32) {
    cosited_even = 0,
    midpoint = 1,
};
pub const TessellationDomainOrigin = enum(i32) {
    upper_left = 0,
    lower_left = 1,
};
pub const DriverId = enum(i32) {
    AMD_proprietary = 1,
    AMD_open_source = 2,
    MESA_radv = 3,
    nvidia_proprietary = 4,
    INTEL_proprietary_windows = 5,
    INTEL_open_sourceMESA = 6,
    imagination_proprietary = 7,
    qualcomm_proprietary = 8,
    ARM_proprietary = 9,
    GOOGLE_swiftshader = 10,
    GGP_proprietary = 11,
    broadcom_proprietary = 12,
    MESA_llvmpipe = 13,
    moltenvk = 14,
    coreavi_proprietary = 15,
    JUICE_proprietary = 16,
    verisilicon_proprietary = 17,
    MESA_turnip = 18,
    MESA_v3dv = 19,
    MESA_panvk = 20,
    SAMSUNG_proprietary = 21,
    MESA_venus = 22,
    MESA_dozen = 23,
    MESA_nvk = 24,
    imagination_open_sourceMESA = 25,
    MESA_honeykrisp = 26,
    vulkan_sc_emulation_on_vulkan = 27,
    MESA_kosmickrisp = 28,
};
pub const ShaderFloatControlsIndependence = enum(i32) {
    @"32_only" = 0,
    all = 1,
    none = 2,
};
pub const SemaphoreType = enum(i32) {
    binary = 0,
    timeline = 1,
};
pub const SamplerReductionMode = enum(i32) {
    weighted_average = 0,
    min = 1,
    max = 2,
};
pub const PresentModeKHR = enum(i32) {
    immediate = 0,
    mailbox = 1,
    fifo = 2,
    fifo_relaxed = 3,
};
pub const ColorSpaceKHR = enum(i32) {
    srgb_nonlinear = 0,
};
pub const FormatFeatureFlags = packed struct(u32) {
    sampled_image: bool = false,
    storage_image: bool = false,
    storage_image_atomic: bool = false,
    uniform_texel_buffer: bool = false,
    storage_texel_buffer: bool = false,
    storage_texel_buffer_atomic: bool = false,
    vertex_buffer: bool = false,
    color_attachment: bool = false,
    color_attachment_blend: bool = false,
    depth_stencil_attachment: bool = false,
    blit_src: bool = false,
    blit_dst: bool = false,
    sampled_image_filter_linear: bool = false,
    _padding0: u1 = 0,
    transfer_src: bool = false,
    transfer_dst: bool = false,
    sampled_image_filter_minmax: bool = false,
    midpoint_chroma_samples: bool = false,
    sampled_image_ycbcr_conversion_linear_filter: bool = false,
    sampled_image_ycbcr_conversion_separate_reconstruction_filter: bool = false,
    sampled_image_ycbcr_conversion_chroma_reconstruction_explicit: bool = false,
    sampled_image_ycbcr_conversion_chroma_reconstruction_explicit_forceable: bool = false,
    disjoint: bool = false,
    cosited_chroma_samples: bool = false,
    _padding1: u8 = 0,
};
pub const ImageCreateFlags = packed struct(u32) {
    sparse_binding: bool = false,
    sparse_residency: bool = false,
    sparse_aliased: bool = false,
    mutable_format: bool = false,
    cube_compatible: bool = false,
    @"2d_array_compatible": bool = false,
    split_instance_bind_regions: bool = false,
    block_texel_view_compatible: bool = false,
    extended_usage: bool = false,
    disjoint: bool = false,
    alias: bool = false,
    protected: bool = false,
    _padding0: u20 = 0,
};
pub const SampleCountFlags = packed struct(u32) {
    @"1": bool = false,
    @"2": bool = false,
    @"4": bool = false,
    @"8": bool = false,
    @"16": bool = false,
    @"32": bool = false,
    @"64": bool = false,
    _padding0: u25 = 0,
};
pub const ImageUsageFlags = packed struct(u32) {
    transfer_src: bool = false,
    transfer_dst: bool = false,
    sampled: bool = false,
    storage: bool = false,
    color_attachment: bool = false,
    depth_stencil_attachment: bool = false,
    transient_attachment: bool = false,
    input_attachment: bool = false,
    _padding0: u24 = 0,
};
pub const InstanceCreateFlags = packed struct(u32) {
    _padding0: u32 = 0,
};
pub const MemoryHeapFlags = packed struct(u32) {
    device_local: bool = false,
    multi_instance: bool = false,
    _padding0: u30 = 0,
};
pub const MemoryPropertyFlags = packed struct(u32) {
    device_local: bool = false,
    host_visible: bool = false,
    host_coherent: bool = false,
    host_cached: bool = false,
    lazily_allocated: bool = false,
    protected: bool = false,
    _padding0: u26 = 0,
};
pub const QueueFlags = packed struct(u32) {
    graphics: bool = false,
    compute: bool = false,
    transfer: bool = false,
    sparse_binding: bool = false,
    protected: bool = false,
    _padding0: u27 = 0,
};
pub const ShaderStageFlags = packed struct(u32) {
    vertex: bool = false,
    tessellation_control: bool = false,
    tessellation_evaluation: bool = false,
    geometry: bool = false,
    fragment: bool = false,
    compute: bool = false,
    _padding0: u26 = 0,
};
pub const DeviceCreateFlags = u32; //unused flag type
pub const DeviceQueueCreateFlags = packed struct(u32) {
    protected: bool = false,
    _padding0: u31 = 0,
};
pub const PipelineStageFlags = packed struct(u32) {
    top_of_pipe: bool = false,
    draw_indirect: bool = false,
    vertex_input: bool = false,
    vertex_shader: bool = false,
    tessellation_control_shader: bool = false,
    tessellation_evaluation_shader: bool = false,
    geometry_shader: bool = false,
    fragment_shader: bool = false,
    early_fragment_tests: bool = false,
    late_fragment_tests: bool = false,
    color_attachment_output: bool = false,
    compute_shader: bool = false,
    transfer: bool = false,
    bottom_of_pipe: bool = false,
    host: bool = false,
    all_graphics: bool = false,
    all_commands: bool = false,
    _padding0: u15 = 0,
};
pub const MemoryMapFlags = packed struct(u32) {
    _padding0: u32 = 0,
};
pub const ImageAspectFlags = packed struct(u32) {
    color: bool = false,
    depth: bool = false,
    stencil: bool = false,
    metadata: bool = false,
    plane_0: bool = false,
    plane_1: bool = false,
    plane_2: bool = false,
    _padding0: u25 = 0,
};
pub const SparseImageFormatFlags = packed struct(u32) {
    single_miptail: bool = false,
    aligned_mip_size: bool = false,
    nonstandard_block_size: bool = false,
    _padding0: u29 = 0,
};
pub const SparseMemoryBindFlags = packed struct(u32) {
    metadata: bool = false,
    _padding0: u31 = 0,
};
pub const FenceCreateFlags = packed struct(u32) {
    signaled: bool = false,
    _padding0: u31 = 0,
};
pub const SemaphoreCreateFlags = u32; //unused flag type
pub const QueryPoolCreateFlags = packed struct(u32) {
    _padding0: u32 = 0,
};
pub const QueryPipelineStatisticFlags = packed struct(u32) {
    input_assembly_vertices: bool = false,
    input_assembly_primitives: bool = false,
    vertex_shader_invocations: bool = false,
    geometry_shader_invocations: bool = false,
    geometry_shader_primitives: bool = false,
    clipping_invocations: bool = false,
    clipping_primitives: bool = false,
    fragment_shader_invocations: bool = false,
    tessellation_control_shader_patches: bool = false,
    tessellation_evaluation_shader_invocations: bool = false,
    compute_shader_invocations: bool = false,
    _padding0: u21 = 0,
};
pub const QueryResultFlags = packed struct(u32) {
    @"64": bool = false,
    wait: bool = false,
    with_availability: bool = false,
    partial: bool = false,
    _padding0: u28 = 0,
};
pub const BufferCreateFlags = packed struct(u32) {
    sparse_binding: bool = false,
    sparse_residency: bool = false,
    sparse_aliased: bool = false,
    protected: bool = false,
    device_address_capture_replay: bool = false,
    _padding0: u27 = 0,
};
pub const BufferUsageFlags = packed struct(u32) {
    transfer_src: bool = false,
    transfer_dst: bool = false,
    uniform_texel_buffer: bool = false,
    storage_texel_buffer: bool = false,
    uniform_buffer: bool = false,
    storage_buffer: bool = false,
    index_buffer: bool = false,
    vertex_buffer: bool = false,
    indirect_buffer: bool = false,
    _padding0: u8 = 0,
    shader_device_address: bool = false,
    _padding1: u14 = 0,
};
pub const ImageViewCreateFlags = packed struct(u32) {
    _padding0: u32 = 0,
};
pub const AccessFlags = packed struct(u32) {
    indirect_command_read: bool = false,
    index_read: bool = false,
    vertex_attribute_read: bool = false,
    uniform_read: bool = false,
    input_attachment_read: bool = false,
    shader_read: bool = false,
    shader_write: bool = false,
    color_attachment_read: bool = false,
    color_attachment_write: bool = false,
    depth_stencil_attachment_read: bool = false,
    depth_stencil_attachment_write: bool = false,
    transfer_read: bool = false,
    transfer_write: bool = false,
    host_read: bool = false,
    host_write: bool = false,
    memory_read: bool = false,
    memory_write: bool = false,
    _padding0: u15 = 0,
};
pub const DependencyFlags = packed struct(u32) {
    by_region: bool = false,
    view_local: bool = false,
    device_group: bool = false,
    _padding0: u29 = 0,
};
pub const CommandPoolCreateFlags = packed struct(u32) {
    transient: bool = false,
    reset_command_buffer: bool = false,
    protected: bool = false,
    _padding0: u29 = 0,
};
pub const CommandPoolResetFlags = packed struct(u32) {
    release_resources: bool = false,
    _padding0: u31 = 0,
};
pub const QueryControlFlags = packed struct(u32) {
    precise: bool = false,
    _padding0: u31 = 0,
};
pub const CommandBufferUsageFlags = packed struct(u32) {
    one_time_submit: bool = false,
    render_pass_continue: bool = false,
    simultaneous_use: bool = false,
    _padding0: u29 = 0,
};
pub const CommandBufferResetFlags = packed struct(u32) {
    release_resources: bool = false,
    _padding0: u31 = 0,
};
pub const EventCreateFlags = packed struct(u32) {
    device_only: bool = false,
    _padding0: u31 = 0,
};
pub const BufferViewCreateFlags = u32; //unused flag type
pub const ShaderModuleCreateFlags = u32; //unused flag type
pub const PipelineCacheCreateFlags = packed struct(u32) {
    externally_synchronized: bool = false,
    _padding0: u31 = 0,
};
pub const PipelineCreateFlags = packed struct(u32) {
    disable_optimization: bool = false,
    allow_derivatives: bool = false,
    derivative: bool = false,
    view_index_from_device_index: bool = false,
    dispatch_base: bool = false,
    _padding0: u3 = 0,
    fail_on_pipeline_compile_required: bool = false,
    early_return_on_failure: bool = false,
    _padding1: u22 = 0,
};
pub const PipelineLayoutCreateFlags = packed struct(u32) {
    _padding0: u32 = 0,
};
pub const PipelineShaderStageCreateFlags = packed struct(u32) {
    allow_varying_subgroup_size: bool = false,
    require_full_subgroups: bool = false,
    _padding0: u30 = 0,
};
pub const SamplerCreateFlags = packed struct(u32) {
    _padding0: u32 = 0,
};
pub const DescriptorPoolCreateFlags = packed struct(u32) {
    free_descriptor_set: bool = false,
    update_after_bind: bool = false,
    _padding0: u30 = 0,
};
pub const DescriptorPoolResetFlags = u32; //unused flag type
pub const DescriptorSetLayoutCreateFlags = packed struct(u32) {
    _padding0: u1 = 0,
    update_after_bind_pool: bool = false,
    _padding1: u30 = 0,
};
pub const ColorComponentFlags = packed struct(u32) {
    r: bool = false,
    g: bool = false,
    b: bool = false,
    a: bool = false,
    _padding0: u28 = 0,
};
pub const CullModeFlags = packed struct(u32) {
    front: bool = false,
    back: bool = false,
    _padding0: u30 = 0,
};
pub const PipelineColorBlendStateCreateFlags = packed struct(u32) {
    _padding0: u32 = 0,
};
pub const PipelineDepthStencilStateCreateFlags = packed struct(u32) {
    _padding0: u32 = 0,
};
pub const PipelineDynamicStateCreateFlags = u32; //unused flag type
pub const PipelineInputAssemblyStateCreateFlags = u32; //unused flag type
pub const PipelineMultisampleStateCreateFlags = u32; //unused flag type
pub const PipelineRasterizationStateCreateFlags = u32; //unused flag type
pub const PipelineTessellationStateCreateFlags = u32; //unused flag type
pub const PipelineVertexInputStateCreateFlags = u32; //unused flag type
pub const PipelineViewportStateCreateFlags = u32; //unused flag type
pub const AttachmentDescriptionFlags = packed struct(u32) {
    may_alias: bool = false,
    _padding0: u31 = 0,
};
pub const FramebufferCreateFlags = packed struct(u32) {
    imageless: bool = false,
    _padding0: u31 = 0,
};
pub const RenderPassCreateFlags = packed struct(u32) {
    _padding0: u32 = 0,
};
pub const SubpassDescriptionFlags = packed struct(u32) {
    _padding0: u32 = 0,
};
pub const StencilFaceFlags = packed struct(u32) {
    front: bool = false,
    back: bool = false,
    _padding0: u30 = 0,
};
pub const SubgroupFeatureFlags = packed struct(u32) {
    basic: bool = false,
    vote: bool = false,
    arithmetic: bool = false,
    ballot: bool = false,
    shuffle: bool = false,
    shuffle_relative: bool = false,
    clustered: bool = false,
    quad: bool = false,
    _padding0: u24 = 0,
};
pub const PeerMemoryFeatureFlags = packed struct(u32) {
    copy_src: bool = false,
    copy_dst: bool = false,
    generic_src: bool = false,
    generic_dst: bool = false,
    _padding0: u28 = 0,
};
pub const MemoryAllocateFlags = packed struct(u32) {
    device_mask: bool = false,
    device_address: bool = false,
    device_address_capture_replay: bool = false,
    _padding0: u29 = 0,
};
pub const CommandPoolTrimFlags = u32; //unused flag type
pub const ExternalMemoryHandleTypeFlags = packed struct(u32) {
    opaque_fd: bool = false,
    opaque_win32: bool = false,
    opaque_win32_kmt: bool = false,
    d3d11_texture: bool = false,
    d3d11_texture_kmt: bool = false,
    d3d12_heap: bool = false,
    d3d12_resource: bool = false,
    _padding0: u25 = 0,
};
pub const ExternalMemoryFeatureFlags = packed struct(u32) {
    dedicated_only: bool = false,
    exportable: bool = false,
    importable: bool = false,
    _padding0: u29 = 0,
};
pub const ExternalFenceHandleTypeFlags = packed struct(u32) {
    opaque_fd: bool = false,
    opaque_win32: bool = false,
    opaque_win32_kmt: bool = false,
    sync_fd: bool = false,
    _padding0: u28 = 0,
};
pub const ExternalFenceFeatureFlags = packed struct(u32) {
    exportable: bool = false,
    importable: bool = false,
    _padding0: u30 = 0,
};
pub const FenceImportFlags = packed struct(u32) {
    temporary: bool = false,
    _padding0: u31 = 0,
};
pub const SemaphoreImportFlags = packed struct(u32) {
    temporary: bool = false,
    _padding0: u31 = 0,
};
pub const ExternalSemaphoreHandleTypeFlags = packed struct(u32) {
    opaque_fd: bool = false,
    opaque_win32: bool = false,
    opaque_win32_kmt: bool = false,
    d3d12_fence: bool = false,
    sync_fd: bool = false,
    _padding0: u27 = 0,
};
pub const ExternalSemaphoreFeatureFlags = packed struct(u32) {
    exportable: bool = false,
    importable: bool = false,
    _padding0: u30 = 0,
};
pub const DescriptorUpdateTemplateCreateFlags = u32; //unused flag type
pub const ResolveModeFlags = packed struct(u32) {
    sample_zero: bool = false,
    average: bool = false,
    min: bool = false,
    max: bool = false,
    _padding0: u28 = 0,
};
pub const SemaphoreWaitFlags = packed struct(u32) {
    any: bool = false,
    _padding0: u31 = 0,
};
pub const DescriptorBindingFlags = packed struct(u32) {
    update_after_bind: bool = false,
    update_unused_while_pending: bool = false,
    partially_bound: bool = false,
    variable_descriptor_count: bool = false,
    _padding0: u28 = 0,
};
pub const ToolPurposeFlags = packed struct(u32) {
    validation: bool = false,
    profiling: bool = false,
    tracing: bool = false,
    additional_features: bool = false,
    modifying_features: bool = false,
    _padding0: u27 = 0,
};
pub const PrivateDataSlotCreateFlags = u32; //unused flag type
pub const PipelineStageFlags2 = packed struct(u64) {
    top_of_pipe: bool = false,
    draw_indirect: bool = false,
    vertex_input: bool = false,
    vertex_shader: bool = false,
    tessellation_control_shader: bool = false,
    tessellation_evaluation_shader: bool = false,
    geometry_shader: bool = false,
    fragment_shader: bool = false,
    early_fragment_tests: bool = false,
    late_fragment_tests: bool = false,
    color_attachment_output: bool = false,
    compute_shader: bool = false,
    all_transfer: bool = false,
    bottom_of_pipe: bool = false,
    host: bool = false,
    all_graphics: bool = false,
    all_commands: bool = false,
    _padding0: u15 = 0,
    copy: bool = false,
    resolve: bool = false,
    blit: bool = false,
    clear: bool = false,
    index_input: bool = false,
    vertex_attribute_input: bool = false,
    pre_rasterization_shaders: bool = false,
    _padding1: u25 = 0,
};
pub const AccessFlags2 = packed struct(u64) {
    indirect_command_read: bool = false,
    index_read: bool = false,
    vertex_attribute_read: bool = false,
    uniform_read: bool = false,
    input_attachment_read: bool = false,
    shader_read: bool = false,
    shader_write: bool = false,
    color_attachment_read: bool = false,
    color_attachment_write: bool = false,
    depth_stencil_attachment_read: bool = false,
    depth_stencil_attachment_write: bool = false,
    transfer_read: bool = false,
    transfer_write: bool = false,
    host_read: bool = false,
    host_write: bool = false,
    memory_read: bool = false,
    memory_write: bool = false,
    _padding0: u15 = 0,
    shader_sampled_read: bool = false,
    shader_storage_read: bool = false,
    shader_storage_write: bool = false,
    _padding1: u29 = 0,
};
pub const SubmitFlags = packed struct(u32) {
    protected: bool = false,
    _padding0: u31 = 0,
};
pub const FormatFeatureFlags2 = packed struct(u64) {
    sampled_image: bool = false,
    storage_image: bool = false,
    storage_image_atomic: bool = false,
    uniform_texel_buffer: bool = false,
    storage_texel_buffer: bool = false,
    storage_texel_buffer_atomic: bool = false,
    vertex_buffer: bool = false,
    color_attachment: bool = false,
    color_attachment_blend: bool = false,
    depth_stencil_attachment: bool = false,
    blit_src: bool = false,
    blit_dst: bool = false,
    sampled_image_filter_linear: bool = false,
    sampled_image_filter_cubic: bool = false,
    transfer_src: bool = false,
    transfer_dst: bool = false,
    sampled_image_filter_minmax: bool = false,
    midpoint_chroma_samples: bool = false,
    sampled_image_ycbcr_conversion_linear_filter: bool = false,
    sampled_image_ycbcr_conversion_separate_reconstruction_filter: bool = false,
    sampled_image_ycbcr_conversion_chroma_reconstruction_explicit: bool = false,
    sampled_image_ycbcr_conversion_chroma_reconstruction_explicit_forceable: bool = false,
    disjoint: bool = false,
    cosited_chroma_samples: bool = false,
    _padding0: u7 = 0,
    storage_read_without_format: bool = false,
    storage_write_without_format: bool = false,
    sampled_image_depth_comparison: bool = false,
    _padding1: u30 = 0,
};
pub const PipelineCreationFeedbackFlags = packed struct(u32) {
    valid: bool = false,
    application_pipeline_cache_hit: bool = false,
    base_pipeline_acceleration: bool = false,
    _padding0: u29 = 0,
};
pub const RenderingFlags = packed struct(u32) {
    contents_secondary_command_buffers: bool = false,
    suspending: bool = false,
    resuming: bool = false,
    _padding0: u29 = 0,
};
pub const SurfaceTransformFlagsKHR = packed struct(u32) {
    identity: bool = false,
    rotate_90: bool = false,
    rotate_180: bool = false,
    rotate_270: bool = false,
    horizontal_mirror: bool = false,
    horizontal_mirror_rotate_90: bool = false,
    horizontal_mirror_rotate_180: bool = false,
    horizontal_mirror_rotate_270: bool = false,
    inherit: bool = false,
    _padding0: u23 = 0,
};
pub const CompositeAlphaFlagsKHR = packed struct(u32) {
    @"opaque": bool = false,
    pre_multiplied: bool = false,
    post_multiplied: bool = false,
    inherit: bool = false,
    _padding0: u28 = 0,
};
pub const SwapchainCreateFlagsKHR = packed struct(u32) {
    split_instance_bind_regions: bool = false,
    protected: bool = false,
    _padding0: u30 = 0,
};
pub const DeviceGroupPresentModeFlagsKHR = packed struct(u32) {
    local: bool = false,
    remote: bool = false,
    sum: bool = false,
    local_multi_device: bool = false,
    _padding0: u28 = 0,
};
pub const DebugUtilsMessengerCallbackDataFlagsEXT = u32; //unused flag type
pub const DebugUtilsMessageTypeFlagsEXT = packed struct(u32) {
    general: bool = false,
    validation: bool = false,
    performance: bool = false,
    _padding0: u29 = 0,
};
pub const DebugUtilsMessageSeverityFlagsEXT = packed struct(u32) {
    verbose: bool = false,
    _padding0: u3 = 0,
    info: bool = false,
    _padding1: u3 = 0,
    warning: bool = false,
    _padding2: u3 = 0,
    @"error": bool = false,
    _padding3: u19 = 0,
};
pub const DebugUtilsMessengerCreateFlagsEXT = u32; //unused flag type
const Instance_t = opaque {};
pub const Instance = *Instance_t;
const PhysicalDevice_t = opaque {};
pub const PhysicalDevice = *PhysicalDevice_t;
const Device_t = opaque {};
pub const Device = *Device_t;
const Queue_t = opaque {};
pub const Queue = *Queue_t;
const Semaphore_t = opaque {};
pub const Semaphore = *Semaphore_t;
const CommandBuffer_t = opaque {};
pub const CommandBuffer = *CommandBuffer_t;
const Fence_t = opaque {};
pub const Fence = *Fence_t;
const DeviceMemory_t = opaque {};
pub const DeviceMemory = *DeviceMemory_t;
const Buffer_t = opaque {};
pub const Buffer = *Buffer_t;
const Image_t = opaque {};
pub const Image = *Image_t;
const QueryPool_t = opaque {};
pub const QueryPool = *QueryPool_t;
const ImageView_t = opaque {};
pub const ImageView = *ImageView_t;
const CommandPool_t = opaque {};
pub const CommandPool = *CommandPool_t;
const RenderPass_t = opaque {};
pub const RenderPass = *RenderPass_t;
const Framebuffer_t = opaque {};
pub const Framebuffer = *Framebuffer_t;
const Event_t = opaque {};
pub const Event = *Event_t;
const BufferView_t = opaque {};
pub const BufferView = *BufferView_t;
const ShaderModule_t = opaque {};
pub const ShaderModule = *ShaderModule_t;
const PipelineCache_t = opaque {};
pub const PipelineCache = *PipelineCache_t;
const Pipeline_t = opaque {};
pub const Pipeline = *Pipeline_t;
const PipelineLayout_t = opaque {};
pub const PipelineLayout = *PipelineLayout_t;
const DescriptorSetLayout_t = opaque {};
pub const DescriptorSetLayout = *DescriptorSetLayout_t;
const Sampler_t = opaque {};
pub const Sampler = *Sampler_t;
const DescriptorSet_t = opaque {};
pub const DescriptorSet = *DescriptorSet_t;
const DescriptorPool_t = opaque {};
pub const DescriptorPool = *DescriptorPool_t;
const DescriptorUpdateTemplate_t = opaque {};
pub const DescriptorUpdateTemplate = *DescriptorUpdateTemplate_t;
const SamplerYcbcrConversion_t = opaque {};
pub const SamplerYcbcrConversion = *SamplerYcbcrConversion_t;
const PrivateDataSlot_t = opaque {};
pub const PrivateDataSlot = *PrivateDataSlot_t;
const SurfaceKHR_t = opaque {};
pub const SurfaceKHR = *SurfaceKHR_t;
const SwapchainKHR_t = opaque {};
pub const SwapchainKHR = *SwapchainKHR_t;
const DebugUtilsMessengerEXT_t = opaque {};
pub const DebugUtilsMessengerEXT = *DebugUtilsMessengerEXT_t;
pub const MaxPhysicalDeviceNameSize = 256;
pub const UuidSize = 16;
pub const LuidSize = 8;
pub const MaxExtensionNameSize = 256;
pub const MaxDescriptionSize = 256;
pub const MaxMemoryTypes = 32;
pub const MaxMemoryHeaps = 16;
pub const LodClampNone = 1000.0;
pub const RemainingMipLevels = 4294967295;
pub const RemainingArrayLayers = 4294967295;
pub const Remaining3dSlicesEXT = 4294967295;
pub const WholeSize = 18446744073709551615;
pub const AttachmentUnused = 4294967295;
pub const True = 1;
pub const False = 0;
pub const QueueFamilyIgnored = 4294967295;
pub const QueueFamilyExternal = 4294967294;
pub const QueueFamilyForeignEXT = 4294967293;
pub const SubpassExternal = 4294967295;
pub const MaxDeviceGroupSize = 32;
pub const MaxDriverNameSize = 256;
pub const MaxDriverInfoSize = 256;
pub const ShaderUnusedKHR = 4294967295;
pub const MaxGlobalPrioritySize = 16;
pub const MaxShaderModuleIdentifierSizeEXT = 32;
pub const MaxPipelineBinaryKeySizeKHR = 32;
pub const MaxVideoAv1ReferencesPerFrameKHR = 7;
pub const MaxVideoVp9ReferencesPerFrameKHR = 3;
pub const ShaderIndexUnusedAMDX = 4294967295;
pub const PartitionedAccelerationStructurePartitionIndexGlobalNV = 4294967295;
pub const CompressedTriangleFormatDgf1ByteAlignmentAMDX = 128;
pub const CompressedTriangleFormatDgf1ByteStrideAMDX = 128;
pub const MaxPhysicalDeviceDataGraphOperationSetNameSizeARM = 128;
pub const DataGraphModelToolchainVersionLengthQCOM = 3;
pub const ComputeOccupancyPriorityLowNV = 0.25;
pub const ComputeOccupancyPriorityNormalNV = 0.5;
pub const ComputeOccupancyPriorityHighNV = 0.75;
pub const MaxDataGraphTosaNameSizeARM = 128;
pub const DebugUtilsLabelEXT = extern struct {
    sType: StructureType = .debug_utils_labelEXT,
    pNext: ?*const anyopaque = null,
    pLabelName: [*:0]const u8 = undefined,
    color: [4]f32 = @splat(0),
};
pub const DebugUtilsObjectNameInfoEXT = extern struct {
    sType: StructureType = .debug_utils_object_name_infoEXT,
    pNext: ?*const anyopaque = null,
    objectType: ObjectType = .unknown,
    objectHandle: u64 = 0,
    pObjectName: ?[*:0]const u8 = null,
};
pub const DebugUtilsMessengerCallbackDataEXT = extern struct {
    sType: StructureType = .debug_utils_messenger_callback_dataEXT,
    pNext: ?*const anyopaque = null,
    flags: DebugUtilsMessengerCallbackDataFlagsEXT = std.mem.zeroes(DebugUtilsMessengerCallbackDataFlagsEXT),
    pMessageIdName: ?[*:0]const u8 = null,
    messageIdNumber: i32 = 0,
    pMessage: ?[*:0]const u8 = null,
    queueLabelCount: u32 = 0,
    pQueueLabels: [*]const DebugUtilsLabelEXT = undefined,
    cmdBufLabelCount: u32 = 0,
    pCmdBufLabels: [*]const DebugUtilsLabelEXT = undefined,
    objectCount: u32 = 0,
    pObjects: [*]const DebugUtilsObjectNameInfoEXT = undefined,
};
pub const Extent2D = extern struct {
    width: u32 = 0,
    height: u32 = 0,
};
pub const Extent3D = extern struct {
    width: u32 = 0,
    height: u32 = 0,
    depth: u32 = 0,
};
pub const Offset2D = extern struct {
    x: i32 = 0,
    y: i32 = 0,
};
pub const Offset3D = extern struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
};
pub const Rect2D = extern struct {
    offset: Offset2D = .{},
    extent: Extent2D = .{},
};
pub const BaseInStructure = extern struct {
    sType: StructureType,
    pNext: ?*const BaseInStructure = null,
};
pub const BaseOutStructure = extern struct {
    sType: StructureType,
    pNext: ?*BaseOutStructure = null,
};
pub const AllocationCallbacks = extern struct {
    pUserData: ?*anyopaque = null,
    pfnAllocation: *pfn.AllocationFunction = undefined,
    pfnReallocation: *pfn.ReallocationFunction = undefined,
    pfnFree: *pfn.FreeFunction = undefined,
    pfnInternalAllocation: ?*pfn.InternalAllocationNotification = null,
    pfnInternalFree: ?*pfn.InternalFreeNotification = null,
};
pub const ApplicationInfo = extern struct {
    sType: StructureType = .application_info,
    pNext: ?*const anyopaque = null,
    pApplicationName: ?[*:0]const u8 = null,
    applicationVersion: u32 = 0,
    pEngineName: ?[*:0]const u8 = null,
    engineVersion: u32 = 0,
    apiVersion: u32 = 0,
};
pub const FormatProperties = extern struct {
    linearTilingFeatures: FormatFeatureFlags = .{},
    optimalTilingFeatures: FormatFeatureFlags = .{},
    bufferFeatures: FormatFeatureFlags = .{},
};
pub const ImageFormatProperties = extern struct {
    maxExtent: Extent3D = .{},
    maxMipLevels: u32 = 0,
    maxArrayLayers: u32 = 0,
    sampleCounts: SampleCountFlags = .{},
    maxResourceSize: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const InstanceCreateInfo = extern struct {
    sType: StructureType = .instance_create_info,
    pNext: ?*const anyopaque = null,
    flags: InstanceCreateFlags = .{},
    pApplicationInfo: ?*const ApplicationInfo = null,
    enabledLayerCount: u32 = 0,
    ppEnabledLayerNames: [*]const [*:0]const u8 = undefined,
    enabledExtensionCount: u32 = 0,
    ppEnabledExtensionNames: [*]const [*:0]const u8 = undefined,
};
pub const MemoryHeap = extern struct {
    size: DeviceSize = std.mem.zeroes(DeviceSize),
    flags: MemoryHeapFlags = .{},
};
pub const MemoryType = extern struct {
    propertyFlags: MemoryPropertyFlags = .{},
    heapIndex: u32 = 0,
};
pub const PhysicalDeviceFeatures = extern struct {
    robustBufferAccess: Bool = .False,
    fullDrawIndexUint32: Bool = .False,
    imageCubeArray: Bool = .False,
    independentBlend: Bool = .False,
    geometryShader: Bool = .False,
    tessellationShader: Bool = .False,
    sampleRateShading: Bool = .False,
    dualSrcBlend: Bool = .False,
    logicOp: Bool = .False,
    multiDrawIndirect: Bool = .False,
    drawIndirectFirstInstance: Bool = .False,
    depthClamp: Bool = .False,
    depthBiasClamp: Bool = .False,
    fillModeNonSolid: Bool = .False,
    depthBounds: Bool = .False,
    wideLines: Bool = .False,
    largePoints: Bool = .False,
    alphaToOne: Bool = .False,
    multiViewport: Bool = .False,
    samplerAnisotropy: Bool = .False,
    textureCompressionETC2: Bool = .False,
    textureCompressionASTC_LDR: Bool = .False,
    textureCompressionBC: Bool = .False,
    occlusionQueryPrecise: Bool = .False,
    pipelineStatisticsQuery: Bool = .False,
    vertexPipelineStoresAndAtomics: Bool = .False,
    fragmentStoresAndAtomics: Bool = .False,
    shaderTessellationAndGeometryPointSize: Bool = .False,
    shaderImageGatherExtended: Bool = .False,
    shaderStorageImageExtendedFormats: Bool = .False,
    shaderStorageImageMultisample: Bool = .False,
    shaderStorageImageReadWithoutFormat: Bool = .False,
    shaderStorageImageWriteWithoutFormat: Bool = .False,
    shaderUniformBufferArrayDynamicIndexing: Bool = .False,
    shaderSampledImageArrayDynamicIndexing: Bool = .False,
    shaderStorageBufferArrayDynamicIndexing: Bool = .False,
    shaderStorageImageArrayDynamicIndexing: Bool = .False,
    shaderClipDistance: Bool = .False,
    shaderCullDistance: Bool = .False,
    shaderFloat64: Bool = .False,
    shaderInt64: Bool = .False,
    shaderInt16: Bool = .False,
    shaderResourceResidency: Bool = .False,
    shaderResourceMinLod: Bool = .False,
    sparseBinding: Bool = .False,
    sparseResidencyBuffer: Bool = .False,
    sparseResidencyImage2D: Bool = .False,
    sparseResidencyImage3D: Bool = .False,
    sparseResidency2Samples: Bool = .False,
    sparseResidency4Samples: Bool = .False,
    sparseResidency8Samples: Bool = .False,
    sparseResidency16Samples: Bool = .False,
    sparseResidencyAliased: Bool = .False,
    variableMultisampleRate: Bool = .False,
    inheritedQueries: Bool = .False,
};
pub const PhysicalDeviceLimits = extern struct {
    maxImageDimension1D: u32 = 0,
    maxImageDimension2D: u32 = 0,
    maxImageDimension3D: u32 = 0,
    maxImageDimensionCube: u32 = 0,
    maxImageArrayLayers: u32 = 0,
    maxTexelBufferElements: u32 = 0,
    maxUniformBufferRange: u32 = 0,
    maxStorageBufferRange: u32 = 0,
    maxPushConstantsSize: u32 = 0,
    maxMemoryAllocationCount: u32 = 0,
    maxSamplerAllocationCount: u32 = 0,
    bufferImageGranularity: DeviceSize = std.mem.zeroes(DeviceSize),
    sparseAddressSpaceSize: DeviceSize = std.mem.zeroes(DeviceSize),
    maxBoundDescriptorSets: u32 = 0,
    maxPerStageDescriptorSamplers: u32 = 0,
    maxPerStageDescriptorUniformBuffers: u32 = 0,
    maxPerStageDescriptorStorageBuffers: u32 = 0,
    maxPerStageDescriptorSampledImages: u32 = 0,
    maxPerStageDescriptorStorageImages: u32 = 0,
    maxPerStageDescriptorInputAttachments: u32 = 0,
    maxPerStageResources: u32 = 0,
    maxDescriptorSetSamplers: u32 = 0,
    maxDescriptorSetUniformBuffers: u32 = 0,
    maxDescriptorSetUniformBuffersDynamic: u32 = 0,
    maxDescriptorSetStorageBuffers: u32 = 0,
    maxDescriptorSetStorageBuffersDynamic: u32 = 0,
    maxDescriptorSetSampledImages: u32 = 0,
    maxDescriptorSetStorageImages: u32 = 0,
    maxDescriptorSetInputAttachments: u32 = 0,
    maxVertexInputAttributes: u32 = 0,
    maxVertexInputBindings: u32 = 0,
    maxVertexInputAttributeOffset: u32 = 0,
    maxVertexInputBindingStride: u32 = 0,
    maxVertexOutputComponents: u32 = 0,
    maxTessellationGenerationLevel: u32 = 0,
    maxTessellationPatchSize: u32 = 0,
    maxTessellationControlPerVertexInputComponents: u32 = 0,
    maxTessellationControlPerVertexOutputComponents: u32 = 0,
    maxTessellationControlPerPatchOutputComponents: u32 = 0,
    maxTessellationControlTotalOutputComponents: u32 = 0,
    maxTessellationEvaluationInputComponents: u32 = 0,
    maxTessellationEvaluationOutputComponents: u32 = 0,
    maxGeometryShaderInvocations: u32 = 0,
    maxGeometryInputComponents: u32 = 0,
    maxGeometryOutputComponents: u32 = 0,
    maxGeometryOutputVertices: u32 = 0,
    maxGeometryTotalOutputComponents: u32 = 0,
    maxFragmentInputComponents: u32 = 0,
    maxFragmentOutputAttachments: u32 = 0,
    maxFragmentDualSrcAttachments: u32 = 0,
    maxFragmentCombinedOutputResources: u32 = 0,
    maxComputeSharedMemorySize: u32 = 0,
    maxComputeWorkGroupCount: [3]u32 = @splat(0),
    maxComputeWorkGroupInvocations: u32 = 0,
    maxComputeWorkGroupSize: [3]u32 = @splat(0),
    subPixelPrecisionBits: u32 = 0,
    subTexelPrecisionBits: u32 = 0,
    mipmapPrecisionBits: u32 = 0,
    maxDrawIndexedIndexValue: u32 = 0,
    maxDrawIndirectCount: u32 = 0,
    maxSamplerLodBias: f32 = 0,
    maxSamplerAnisotropy: f32 = 0,
    maxViewports: u32 = 0,
    maxViewportDimensions: [2]u32 = @splat(0),
    viewportBoundsRange: [2]f32 = @splat(0),
    viewportSubPixelBits: u32 = 0,
    minMemoryMapAlignment: u64 = std.mem.zeroes(u64),
    minTexelBufferOffsetAlignment: DeviceSize = std.mem.zeroes(DeviceSize),
    minUniformBufferOffsetAlignment: DeviceSize = std.mem.zeroes(DeviceSize),
    minStorageBufferOffsetAlignment: DeviceSize = std.mem.zeroes(DeviceSize),
    minTexelOffset: i32 = 0,
    maxTexelOffset: u32 = 0,
    minTexelGatherOffset: i32 = 0,
    maxTexelGatherOffset: u32 = 0,
    minInterpolationOffset: f32 = 0,
    maxInterpolationOffset: f32 = 0,
    subPixelInterpolationOffsetBits: u32 = 0,
    maxFramebufferWidth: u32 = 0,
    maxFramebufferHeight: u32 = 0,
    maxFramebufferLayers: u32 = 0,
    framebufferColorSampleCounts: SampleCountFlags = .{},
    framebufferDepthSampleCounts: SampleCountFlags = .{},
    framebufferStencilSampleCounts: SampleCountFlags = .{},
    framebufferNoAttachmentsSampleCounts: SampleCountFlags = .{},
    maxColorAttachments: u32 = 0,
    sampledImageColorSampleCounts: SampleCountFlags = .{},
    sampledImageIntegerSampleCounts: SampleCountFlags = .{},
    sampledImageDepthSampleCounts: SampleCountFlags = .{},
    sampledImageStencilSampleCounts: SampleCountFlags = .{},
    storageImageSampleCounts: SampleCountFlags = .{},
    maxSampleMaskWords: u32 = 0,
    timestampComputeAndGraphics: Bool = .False,
    timestampPeriod: f32 = 0,
    maxClipDistances: u32 = 0,
    maxCullDistances: u32 = 0,
    maxCombinedClipAndCullDistances: u32 = 0,
    discreteQueuePriorities: u32 = 0,
    pointSizeRange: [2]f32 = @splat(0),
    lineWidthRange: [2]f32 = @splat(0),
    pointSizeGranularity: f32 = 0,
    lineWidthGranularity: f32 = 0,
    strictLines: Bool = .False,
    standardSampleLocations: Bool = .False,
    optimalBufferCopyOffsetAlignment: DeviceSize = std.mem.zeroes(DeviceSize),
    optimalBufferCopyRowPitchAlignment: DeviceSize = std.mem.zeroes(DeviceSize),
    nonCoherentAtomSize: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const PhysicalDeviceMemoryProperties = extern struct {
    memoryTypeCount: u32 = 0,
    memoryTypes: [MaxMemoryTypes]MemoryType = @splat(.{}),
    memoryHeapCount: u32 = 0,
    memoryHeaps: [MaxMemoryHeaps]MemoryHeap = @splat(.{}),
};
pub const PhysicalDeviceSparseProperties = extern struct {
    residencyStandard2DBlockShape: Bool = .False,
    residencyStandard2DMultisampleBlockShape: Bool = .False,
    residencyStandard3DBlockShape: Bool = .False,
    residencyAlignedMipSize: Bool = .False,
    residencyNonResidentStrict: Bool = .False,
};
pub const PhysicalDeviceProperties = extern struct {
    apiVersion: u32 = 0,
    driverVersion: u32 = 0,
    vendorID: u32 = 0,
    deviceID: u32 = 0,
    deviceType: PhysicalDeviceType = .other,
    deviceName: [MaxPhysicalDeviceNameSize]u8 = @splat(0),
    pipelineCacheUUID: [UuidSize]u8 = @splat(0),
    limits: PhysicalDeviceLimits = .{},
    sparseProperties: PhysicalDeviceSparseProperties = .{},
};
pub const QueueFamilyProperties = extern struct {
    queueFlags: QueueFlags = .{},
    queueCount: u32 = 0,
    timestampValidBits: u32 = 0,
    minImageTransferGranularity: Extent3D = .{},
};
pub const DeviceQueueCreateInfo = extern struct {
    sType: StructureType = .device_queue_create_info,
    pNext: ?*const anyopaque = null,
    flags: DeviceQueueCreateFlags = .{},
    queueFamilyIndex: u32 = 0,
    queueCount: u32 = 0,
    pQueuePriorities: [*]const f32 = undefined,
};
pub const DeviceCreateInfo = extern struct {
    sType: StructureType = .device_create_info,
    pNext: ?*const anyopaque = null,
    flags: DeviceCreateFlags = std.mem.zeroes(DeviceCreateFlags),
    queueCreateInfoCount: u32 = 0,
    pQueueCreateInfos: [*]const DeviceQueueCreateInfo = undefined,
    enabledLayerCount: u32 = 0,
    ppEnabledLayerNames: ?[*]const *const u8 = null,
    enabledExtensionCount: u32 = 0,
    ppEnabledExtensionNames: [*]const [*:0]const u8 = undefined,
    pEnabledFeatures: ?*const PhysicalDeviceFeatures = null,
};
pub const ExtensionProperties = extern struct {
    extensionName: [MaxExtensionNameSize]u8 = @splat(0),
    specVersion: u32 = 0,
};
pub const LayerProperties = extern struct {
    layerName: [MaxExtensionNameSize]u8 = @splat(0),
    specVersion: u32 = 0,
    implementationVersion: u32 = 0,
    description: [MaxDescriptionSize]u8 = @splat(0),
};
pub const SubmitInfo = extern struct {
    sType: StructureType = .submit_info,
    pNext: ?*const anyopaque = null,
    waitSemaphoreCount: u32 = 0,
    pWaitSemaphores: [*]const Semaphore = undefined,
    pWaitDstStageMask: ?[*]const PipelineStageFlags = undefined,
    commandBufferCount: u32 = 0,
    pCommandBuffers: [*]const CommandBuffer = undefined,
    signalSemaphoreCount: u32 = 0,
    pSignalSemaphores: [*]const Semaphore = undefined,
};
pub const MappedMemoryRange = extern struct {
    sType: StructureType = .mapped_memory_range,
    pNext: ?*const anyopaque = null,
    memory: DeviceMemory = undefined,
    offset: DeviceSize = std.mem.zeroes(DeviceSize),
    size: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const MemoryAllocateInfo = extern struct {
    sType: StructureType = .memory_allocate_info,
    pNext: ?*const anyopaque = null,
    allocationSize: DeviceSize = std.mem.zeroes(DeviceSize),
    memoryTypeIndex: u32 = 0,
};
pub const MemoryRequirements = extern struct {
    size: DeviceSize = std.mem.zeroes(DeviceSize),
    alignment: DeviceSize = std.mem.zeroes(DeviceSize),
    memoryTypeBits: u32 = 0,
};
pub const ImageSubresource = extern struct {
    aspectMask: ImageAspectFlags = .{},
    mipLevel: u32 = 0,
    arrayLayer: u32 = 0,
};
pub const SparseImageFormatProperties = extern struct {
    aspectMask: ImageAspectFlags = .{},
    imageGranularity: Extent3D = .{},
    flags: SparseImageFormatFlags = .{},
};
pub const SparseImageMemoryBind = extern struct {
    subresource: ImageSubresource = .{},
    offset: Offset3D = .{},
    extent: Extent3D = .{},
    memory: ?DeviceMemory = null,
    memoryOffset: DeviceSize = std.mem.zeroes(DeviceSize),
    flags: SparseMemoryBindFlags = .{},
};
pub const SparseImageMemoryBindInfo = extern struct {
    image: Image = undefined,
    bindCount: u32 = 0,
    pBinds: [*]const SparseImageMemoryBind = undefined,
};
pub const SparseImageMemoryRequirements = extern struct {
    formatProperties: SparseImageFormatProperties = .{},
    imageMipTailFirstLod: u32 = 0,
    imageMipTailSize: DeviceSize = std.mem.zeroes(DeviceSize),
    imageMipTailOffset: DeviceSize = std.mem.zeroes(DeviceSize),
    imageMipTailStride: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const SparseMemoryBind = extern struct {
    resourceOffset: DeviceSize = std.mem.zeroes(DeviceSize),
    size: DeviceSize = std.mem.zeroes(DeviceSize),
    memory: ?DeviceMemory = null,
    memoryOffset: DeviceSize = std.mem.zeroes(DeviceSize),
    flags: SparseMemoryBindFlags = .{},
};
pub const SparseBufferMemoryBindInfo = extern struct {
    buffer: Buffer = undefined,
    bindCount: u32 = 0,
    pBinds: [*]const SparseMemoryBind = undefined,
};
pub const SparseImageOpaqueMemoryBindInfo = extern struct {
    image: Image = undefined,
    bindCount: u32 = 0,
    pBinds: [*]const SparseMemoryBind = undefined,
};
pub const BindSparseInfo = extern struct {
    sType: StructureType = .bind_sparse_info,
    pNext: ?*const anyopaque = null,
    waitSemaphoreCount: u32 = 0,
    pWaitSemaphores: [*]const Semaphore = undefined,
    bufferBindCount: u32 = 0,
    pBufferBinds: [*]const SparseBufferMemoryBindInfo = undefined,
    imageOpaqueBindCount: u32 = 0,
    pImageOpaqueBinds: [*]const SparseImageOpaqueMemoryBindInfo = undefined,
    imageBindCount: u32 = 0,
    pImageBinds: [*]const SparseImageMemoryBindInfo = undefined,
    signalSemaphoreCount: u32 = 0,
    pSignalSemaphores: [*]const Semaphore = undefined,
};
pub const FenceCreateInfo = extern struct {
    sType: StructureType = .fence_create_info,
    pNext: ?*const anyopaque = null,
    flags: FenceCreateFlags = .{},
};
pub const SemaphoreCreateInfo = extern struct {
    sType: StructureType = .semaphore_create_info,
    pNext: ?*const anyopaque = null,
    flags: SemaphoreCreateFlags = std.mem.zeroes(SemaphoreCreateFlags),
};
pub const QueryPoolCreateInfo = extern struct {
    sType: StructureType = .query_pool_create_info,
    pNext: ?*const anyopaque = null,
    flags: QueryPoolCreateFlags = .{},
    queryType: QueryType = .occlusion,
    queryCount: u32 = 0,
    pipelineStatistics: QueryPipelineStatisticFlags = .{},
};
pub const BufferCreateInfo = extern struct {
    sType: StructureType = .buffer_create_info,
    pNext: ?*const anyopaque = null,
    flags: BufferCreateFlags = .{},
    size: DeviceSize = std.mem.zeroes(DeviceSize),
    usage: BufferUsageFlags = .{},
    sharingMode: SharingMode = .exclusive,
    queueFamilyIndexCount: u32 = 0,
    pQueueFamilyIndices: [*]const u32 = undefined,
};
pub const ImageCreateInfo = extern struct {
    sType: StructureType = .image_create_info,
    pNext: ?*const anyopaque = null,
    flags: ImageCreateFlags = .{},
    imageType: ImageType = .@"1d",
    format: Format = .undefined,
    extent: Extent3D = .{},
    mipLevels: u32 = 0,
    arrayLayers: u32 = 0,
    samples: SampleCountFlags = std.mem.zeroes(SampleCountFlags),
    tiling: ImageTiling = .optimal,
    usage: ImageUsageFlags = .{},
    sharingMode: SharingMode = .exclusive,
    queueFamilyIndexCount: u32 = 0,
    pQueueFamilyIndices: [*]const u32 = undefined,
    initialLayout: ImageLayout = .undefined,
};
pub const SubresourceLayout = extern struct {
    offset: DeviceSize = std.mem.zeroes(DeviceSize),
    size: DeviceSize = std.mem.zeroes(DeviceSize),
    rowPitch: DeviceSize = std.mem.zeroes(DeviceSize),
    arrayPitch: DeviceSize = std.mem.zeroes(DeviceSize),
    depthPitch: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const ComponentMapping = extern struct {
    r: ComponentSwizzle = .identity,
    g: ComponentSwizzle = .identity,
    b: ComponentSwizzle = .identity,
    a: ComponentSwizzle = .identity,
};
pub const ImageSubresourceRange = extern struct {
    aspectMask: ImageAspectFlags = .{},
    baseMipLevel: u32 = 0,
    levelCount: u32 = 0,
    baseArrayLayer: u32 = 0,
    layerCount: u32 = 0,
};
pub const ImageViewCreateInfo = extern struct {
    sType: StructureType = .image_view_create_info,
    pNext: ?*const anyopaque = null,
    flags: ImageViewCreateFlags = .{},
    image: Image = undefined,
    viewType: ImageViewType = .@"1d",
    format: Format = .undefined,
    components: ComponentMapping = .{},
    subresourceRange: ImageSubresourceRange = .{},
};
pub const CommandPoolCreateInfo = extern struct {
    sType: StructureType = .command_pool_create_info,
    pNext: ?*const anyopaque = null,
    flags: CommandPoolCreateFlags = .{},
    queueFamilyIndex: u32 = 0,
};
pub const CommandBufferAllocateInfo = extern struct {
    sType: StructureType = .command_buffer_allocate_info,
    pNext: ?*const anyopaque = null,
    commandPool: CommandPool = undefined,
    level: CommandBufferLevel = .primary,
    commandBufferCount: u32 = 0,
};
pub const CommandBufferInheritanceInfo = extern struct {
    sType: StructureType = .command_buffer_inheritance_info,
    pNext: ?*const anyopaque = null,
    renderPass: ?RenderPass = null,
    subpass: u32 = 0,
    framebuffer: ?Framebuffer = null,
    occlusionQueryEnable: Bool = .False,
    queryFlags: QueryControlFlags = .{},
    pipelineStatistics: QueryPipelineStatisticFlags = .{},
};
pub const CommandBufferBeginInfo = extern struct {
    sType: StructureType = .command_buffer_begin_info,
    pNext: ?*const anyopaque = null,
    flags: CommandBufferUsageFlags = .{},
    pInheritanceInfo: ?*const CommandBufferInheritanceInfo = null,
};
pub const BufferCopy = extern struct {
    srcOffset: DeviceSize = std.mem.zeroes(DeviceSize),
    dstOffset: DeviceSize = std.mem.zeroes(DeviceSize),
    size: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const ImageSubresourceLayers = extern struct {
    aspectMask: ImageAspectFlags = .{},
    mipLevel: u32 = 0,
    baseArrayLayer: u32 = 0,
    layerCount: u32 = 0,
};
pub const BufferImageCopy = extern struct {
    bufferOffset: DeviceSize = std.mem.zeroes(DeviceSize),
    bufferRowLength: u32 = 0,
    bufferImageHeight: u32 = 0,
    imageSubresource: ImageSubresourceLayers = .{},
    imageOffset: Offset3D = .{},
    imageExtent: Extent3D = .{},
};
pub const ImageCopy = extern struct {
    srcSubresource: ImageSubresourceLayers = .{},
    srcOffset: Offset3D = .{},
    dstSubresource: ImageSubresourceLayers = .{},
    dstOffset: Offset3D = .{},
    extent: Extent3D = .{},
};
pub const BufferMemoryBarrier = extern struct {
    sType: StructureType = .buffer_memory_barrier,
    pNext: ?*const anyopaque = null,
    srcAccessMask: AccessFlags = .{},
    dstAccessMask: AccessFlags = .{},
    srcQueueFamilyIndex: u32 = 0,
    dstQueueFamilyIndex: u32 = 0,
    buffer: Buffer = undefined,
    offset: DeviceSize = std.mem.zeroes(DeviceSize),
    size: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const ImageMemoryBarrier = extern struct {
    sType: StructureType = .image_memory_barrier,
    pNext: ?*const anyopaque = null,
    srcAccessMask: AccessFlags = .{},
    dstAccessMask: AccessFlags = .{},
    oldLayout: ImageLayout = .undefined,
    newLayout: ImageLayout = .undefined,
    srcQueueFamilyIndex: u32 = 0,
    dstQueueFamilyIndex: u32 = 0,
    image: Image = undefined,
    subresourceRange: ImageSubresourceRange = .{},
};
pub const MemoryBarrier = extern struct {
    sType: StructureType = .memory_barrier,
    pNext: ?*const anyopaque = null,
    srcAccessMask: AccessFlags = .{},
    dstAccessMask: AccessFlags = .{},
};
pub const DispatchIndirectCommand = extern struct {
    x: u32 = 0,
    y: u32 = 0,
    z: u32 = 0,
};
pub const PipelineCacheHeaderVersionOne = extern struct {
    headerSize: u32 = 0,
    headerVersion: PipelineCacheHeaderVersion,
    vendorID: u32 = 0,
    deviceID: u32 = 0,
    pipelineCacheUUID: [UuidSize]u8 = @splat(0),
};
pub const EventCreateInfo = extern struct {
    sType: StructureType = .event_create_info,
    pNext: ?*const anyopaque = null,
    flags: EventCreateFlags = .{},
};
pub const BufferViewCreateInfo = extern struct {
    sType: StructureType = .buffer_view_create_info,
    pNext: ?*const anyopaque = null,
    flags: BufferViewCreateFlags = std.mem.zeroes(BufferViewCreateFlags),
    buffer: Buffer = undefined,
    format: Format = .undefined,
    offset: DeviceSize = std.mem.zeroes(DeviceSize),
    range: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const ShaderModuleCreateInfo = extern struct {
    sType: StructureType = .shader_module_create_info,
    pNext: ?*const anyopaque = null,
    flags: ShaderModuleCreateFlags = std.mem.zeroes(ShaderModuleCreateFlags),
    codeSize: u64 = std.mem.zeroes(u64),
    pCode: [*]const u32 = undefined,
};
pub const PipelineCacheCreateInfo = extern struct {
    sType: StructureType = .pipeline_cache_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineCacheCreateFlags = .{},
    initialDataSize: u64 = std.mem.zeroes(u64),
    pInitialData: [*]const u8 = undefined,
};
pub const SpecializationMapEntry = extern struct {
    constantID: u32 = 0,
    offset: u32 = 0,
    size: u64 = std.mem.zeroes(u64),
};
pub const SpecializationInfo = extern struct {
    mapEntryCount: u32 = 0,
    pMapEntries: [*]const SpecializationMapEntry = undefined,
    dataSize: u64 = std.mem.zeroes(u64),
    pData: [*]const u8 = undefined,
};
pub const PipelineShaderStageCreateInfo = extern struct {
    sType: StructureType = .pipeline_shader_stage_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineShaderStageCreateFlags = .{},
    stage: ShaderStageFlags = std.mem.zeroes(ShaderStageFlags),
    module: ?ShaderModule = null,
    pName: [*:0]const u8 = undefined,
    pSpecializationInfo: ?*const SpecializationInfo = null,
};
pub const ComputePipelineCreateInfo = extern struct {
    sType: StructureType = .compute_pipeline_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineCreateFlags = .{},
    stage: PipelineShaderStageCreateInfo = .{},
    layout: ?PipelineLayout = null,
    basePipelineHandle: ?Pipeline = null,
    basePipelineIndex: i32 = 0,
};
pub const PushConstantRange = extern struct {
    stageFlags: ShaderStageFlags = .{},
    offset: u32 = 0,
    size: u32 = 0,
};
pub const PipelineLayoutCreateInfo = extern struct {
    sType: StructureType = .pipeline_layout_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineLayoutCreateFlags = .{},
    setLayoutCount: u32 = 0,
    pSetLayouts: ?[*]const DescriptorSetLayout = undefined,
    pushConstantRangeCount: u32 = 0,
    pPushConstantRanges: [*]const PushConstantRange = undefined,
};
pub const SamplerCreateInfo = extern struct {
    sType: StructureType = .sampler_create_info,
    pNext: ?*const anyopaque = null,
    flags: SamplerCreateFlags = .{},
    magFilter: Filter = .nearest,
    minFilter: Filter = .nearest,
    mipmapMode: SamplerMipmapMode = .nearest,
    addressModeU: SamplerAddressMode = .repeat,
    addressModeV: SamplerAddressMode = .repeat,
    addressModeW: SamplerAddressMode = .repeat,
    mipLodBias: f32 = 0,
    anisotropyEnable: Bool = .False,
    maxAnisotropy: f32 = 0,
    compareEnable: Bool = .False,
    compareOp: CompareOp = .never,
    minLod: f32 = 0,
    maxLod: f32 = 0,
    borderColor: BorderColor = .float_transparent_black,
    unnormalizedCoordinates: Bool = .False,
};
pub const CopyDescriptorSet = extern struct {
    sType: StructureType = .copy_descriptor_set,
    pNext: ?*const anyopaque = null,
    srcSet: DescriptorSet = undefined,
    srcBinding: u32 = 0,
    srcArrayElement: u32 = 0,
    dstSet: DescriptorSet = undefined,
    dstBinding: u32 = 0,
    dstArrayElement: u32 = 0,
    descriptorCount: u32 = 0,
};
pub const DescriptorBufferInfo = extern struct {
    buffer: ?Buffer = null,
    offset: DeviceSize = std.mem.zeroes(DeviceSize),
    range: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const DescriptorImageInfo = extern struct {
    sampler: Sampler = undefined,
    imageView: ImageView = undefined,
    imageLayout: ImageLayout = .undefined,
};
pub const DescriptorPoolSize = extern struct {
    type: DescriptorType = .sampler,
    descriptorCount: u32 = 0,
};
pub const DescriptorPoolCreateInfo = extern struct {
    sType: StructureType = .descriptor_pool_create_info,
    pNext: ?*const anyopaque = null,
    flags: DescriptorPoolCreateFlags = .{},
    maxSets: u32 = 0,
    poolSizeCount: u32 = 0,
    pPoolSizes: [*]const DescriptorPoolSize = undefined,
};
pub const DescriptorSetAllocateInfo = extern struct {
    sType: StructureType = .descriptor_set_allocate_info,
    pNext: ?*const anyopaque = null,
    descriptorPool: DescriptorPool = undefined,
    descriptorSetCount: u32 = 0,
    pSetLayouts: [*]const DescriptorSetLayout = undefined,
};
pub const DescriptorSetLayoutBinding = extern struct {
    binding: u32 = 0,
    descriptorType: DescriptorType = .sampler,
    descriptorCount: u32 = 0,
    stageFlags: ShaderStageFlags = .{},
    pImmutableSamplers: ?[*]const Sampler = null,
};
pub const DescriptorSetLayoutCreateInfo = extern struct {
    sType: StructureType = .descriptor_set_layout_create_info,
    pNext: ?*const anyopaque = null,
    flags: DescriptorSetLayoutCreateFlags = .{},
    bindingCount: u32 = 0,
    pBindings: [*]const DescriptorSetLayoutBinding = undefined,
};
pub const WriteDescriptorSet = extern struct {
    sType: StructureType = .write_descriptor_set,
    pNext: ?*const anyopaque = null,
    dstSet: DescriptorSet = undefined,
    dstBinding: u32 = 0,
    dstArrayElement: u32 = 0,
    descriptorCount: u32 = 0,
    descriptorType: DescriptorType = .sampler,
    pImageInfo: [*]const DescriptorImageInfo = undefined,
    pBufferInfo: [*]const DescriptorBufferInfo = undefined,
    pTexelBufferView: [*]const BufferView = undefined,
};
pub const ClearColorValue = extern union {
    float32: [4]f32,
    int32: [4]i32,
    uint32: [4]u32,
};
pub const DrawIndexedIndirectCommand = extern struct {
    indexCount: u32 = 0,
    instanceCount: u32 = 0,
    firstIndex: u32 = 0,
    vertexOffset: i32 = 0,
    firstInstance: u32 = 0,
};
pub const DrawIndirectCommand = extern struct {
    vertexCount: u32 = 0,
    instanceCount: u32 = 0,
    firstVertex: u32 = 0,
    firstInstance: u32 = 0,
};
pub const StencilOpState = extern struct {
    failOp: StencilOp = .keep,
    passOp: StencilOp = .keep,
    depthFailOp: StencilOp = .keep,
    compareOp: CompareOp = .never,
    compareMask: u32 = 0,
    writeMask: u32 = 0,
    reference: u32 = 0,
};
pub const VertexInputAttributeDescription = extern struct {
    location: u32 = 0,
    binding: u32 = 0,
    format: Format = .undefined,
    offset: u32 = 0,
};
pub const VertexInputBindingDescription = extern struct {
    binding: u32 = 0,
    stride: u32 = 0,
    inputRate: VertexInputRate = .vertex,
};
pub const Viewport = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
    minDepth: f32 = 0,
    maxDepth: f32 = 0,
};
pub const PipelineColorBlendAttachmentState = extern struct {
    blendEnable: Bool = .False,
    srcColorBlendFactor: BlendFactor = .zero,
    dstColorBlendFactor: BlendFactor = .zero,
    colorBlendOp: BlendOp = .add,
    srcAlphaBlendFactor: BlendFactor = .zero,
    dstAlphaBlendFactor: BlendFactor = .zero,
    alphaBlendOp: BlendOp = .add,
    colorWriteMask: ColorComponentFlags = .{},
};
pub const PipelineColorBlendStateCreateInfo = extern struct {
    sType: StructureType = .pipeline_color_blend_state_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineColorBlendStateCreateFlags = .{},
    logicOpEnable: Bool = .False,
    logicOp: LogicOp = .clear,
    attachmentCount: u32 = 0,
    pAttachments: ?[*]const PipelineColorBlendAttachmentState = null,
    blendConstants: [4]f32 = @splat(0),
};
pub const PipelineDepthStencilStateCreateInfo = extern struct {
    sType: StructureType = .pipeline_depth_stencil_state_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineDepthStencilStateCreateFlags = .{},
    depthTestEnable: Bool = .False,
    depthWriteEnable: Bool = .False,
    depthCompareOp: CompareOp = .never,
    depthBoundsTestEnable: Bool = .False,
    stencilTestEnable: Bool = .False,
    front: StencilOpState = .{},
    back: StencilOpState = .{},
    minDepthBounds: f32 = 0,
    maxDepthBounds: f32 = 0,
};
pub const PipelineDynamicStateCreateInfo = extern struct {
    sType: StructureType = .pipeline_dynamic_state_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineDynamicStateCreateFlags = std.mem.zeroes(PipelineDynamicStateCreateFlags),
    dynamicStateCount: u32 = 0,
    pDynamicStates: [*]const DynamicState = undefined,
};
pub const PipelineInputAssemblyStateCreateInfo = extern struct {
    sType: StructureType = .pipeline_input_assembly_state_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineInputAssemblyStateCreateFlags = std.mem.zeroes(PipelineInputAssemblyStateCreateFlags),
    topology: PrimitiveTopology = .point_list,
    primitiveRestartEnable: Bool = .False,
};
pub const PipelineMultisampleStateCreateInfo = extern struct {
    sType: StructureType = .pipeline_multisample_state_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineMultisampleStateCreateFlags = std.mem.zeroes(PipelineMultisampleStateCreateFlags),
    rasterizationSamples: SampleCountFlags = std.mem.zeroes(SampleCountFlags),
    sampleShadingEnable: Bool = .False,
    minSampleShading: f32 = 0,
    pSampleMask: ?[*]const u32 = null,
    alphaToCoverageEnable: Bool = .False,
    alphaToOneEnable: Bool = .False,
};
pub const PipelineRasterizationStateCreateInfo = extern struct {
    sType: StructureType = .pipeline_rasterization_state_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineRasterizationStateCreateFlags = std.mem.zeroes(PipelineRasterizationStateCreateFlags),
    depthClampEnable: Bool = .False,
    rasterizerDiscardEnable: Bool = .False,
    polygonMode: PolygonMode = .fill,
    cullMode: CullModeFlags = .{},
    frontFace: FrontFace = .counter_clockwise,
    depthBiasEnable: Bool = .False,
    depthBiasConstantFactor: f32 = 0,
    depthBiasClamp: f32 = 0,
    depthBiasSlopeFactor: f32 = 0,
    lineWidth: f32 = 0,
};
pub const PipelineTessellationStateCreateInfo = extern struct {
    sType: StructureType = .pipeline_tessellation_state_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineTessellationStateCreateFlags = std.mem.zeroes(PipelineTessellationStateCreateFlags),
    patchControlPoints: u32 = 0,
};
pub const PipelineVertexInputStateCreateInfo = extern struct {
    sType: StructureType = .pipeline_vertex_input_state_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineVertexInputStateCreateFlags = std.mem.zeroes(PipelineVertexInputStateCreateFlags),
    vertexBindingDescriptionCount: u32 = 0,
    pVertexBindingDescriptions: [*]const VertexInputBindingDescription = undefined,
    vertexAttributeDescriptionCount: u32 = 0,
    pVertexAttributeDescriptions: [*]const VertexInputAttributeDescription = undefined,
};
pub const PipelineViewportStateCreateInfo = extern struct {
    sType: StructureType = .pipeline_viewport_state_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineViewportStateCreateFlags = std.mem.zeroes(PipelineViewportStateCreateFlags),
    viewportCount: u32 = 0,
    pViewports: ?[*]const Viewport = null,
    scissorCount: u32 = 0,
    pScissors: ?[*]const Rect2D = null,
};
pub const GraphicsPipelineCreateInfo = extern struct {
    sType: StructureType = .graphics_pipeline_create_info,
    pNext: ?*const anyopaque = null,
    flags: PipelineCreateFlags = .{},
    stageCount: u32 = 0,
    pStages: ?[*]const PipelineShaderStageCreateInfo = null,
    pVertexInputState: ?*const PipelineVertexInputStateCreateInfo = null,
    pInputAssemblyState: ?*const PipelineInputAssemblyStateCreateInfo = null,
    pTessellationState: ?*const PipelineTessellationStateCreateInfo = null,
    pViewportState: ?*const PipelineViewportStateCreateInfo = null,
    pRasterizationState: ?*const PipelineRasterizationStateCreateInfo = null,
    pMultisampleState: ?*const PipelineMultisampleStateCreateInfo = null,
    pDepthStencilState: ?*const PipelineDepthStencilStateCreateInfo = null,
    pColorBlendState: ?*const PipelineColorBlendStateCreateInfo = null,
    pDynamicState: ?*const PipelineDynamicStateCreateInfo = null,
    layout: ?PipelineLayout = null,
    renderPass: ?RenderPass = null,
    subpass: u32 = 0,
    basePipelineHandle: ?Pipeline = null,
    basePipelineIndex: i32 = 0,
};
pub const AttachmentDescription = extern struct {
    flags: AttachmentDescriptionFlags = .{},
    format: Format = .undefined,
    samples: SampleCountFlags = std.mem.zeroes(SampleCountFlags),
    loadOp: AttachmentLoadOp = .load,
    storeOp: AttachmentStoreOp = .store,
    stencilLoadOp: AttachmentLoadOp = .load,
    stencilStoreOp: AttachmentStoreOp = .store,
    initialLayout: ImageLayout = .undefined,
    finalLayout: ImageLayout = .undefined,
};
pub const AttachmentReference = extern struct {
    attachment: u32 = 0,
    layout: ImageLayout = .undefined,
};
pub const FramebufferCreateInfo = extern struct {
    sType: StructureType = .framebuffer_create_info,
    pNext: ?*const anyopaque = null,
    flags: FramebufferCreateFlags = .{},
    renderPass: RenderPass = undefined,
    attachmentCount: u32 = 0,
    pAttachments: [*]const ImageView = undefined,
    width: u32 = 0,
    height: u32 = 0,
    layers: u32 = 0,
};
pub const SubpassDependency = extern struct {
    srcSubpass: u32 = 0,
    dstSubpass: u32 = 0,
    srcStageMask: PipelineStageFlags = .{},
    dstStageMask: PipelineStageFlags = .{},
    srcAccessMask: AccessFlags = .{},
    dstAccessMask: AccessFlags = .{},
    dependencyFlags: DependencyFlags = .{},
};
pub const SubpassDescription = extern struct {
    flags: SubpassDescriptionFlags = .{},
    pipelineBindPoint: PipelineBindPoint = .graphics,
    inputAttachmentCount: u32 = 0,
    pInputAttachments: [*]const AttachmentReference = undefined,
    colorAttachmentCount: u32 = 0,
    pColorAttachments: [*]const AttachmentReference = undefined,
    pResolveAttachments: ?[*]const AttachmentReference = null,
    pDepthStencilAttachment: ?*const AttachmentReference = null,
    preserveAttachmentCount: u32 = 0,
    pPreserveAttachments: [*]const u32 = undefined,
};
pub const RenderPassCreateInfo = extern struct {
    sType: StructureType = .render_pass_create_info,
    pNext: ?*const anyopaque = null,
    flags: RenderPassCreateFlags = .{},
    attachmentCount: u32 = 0,
    pAttachments: [*]const AttachmentDescription = undefined,
    subpassCount: u32 = 0,
    pSubpasses: [*]const SubpassDescription = undefined,
    dependencyCount: u32 = 0,
    pDependencies: [*]const SubpassDependency = undefined,
};
pub const ClearDepthStencilValue = extern struct {
    depth: f32 = 0,
    stencil: u32 = 0,
};
pub const ClearRect = extern struct {
    rect: Rect2D = .{},
    baseArrayLayer: u32 = 0,
    layerCount: u32 = 0,
};
pub const ClearValue = extern union {
    color: ClearColorValue,
    depthStencil: ClearDepthStencilValue,
};
pub const ClearAttachment = extern struct {
    aspectMask: ImageAspectFlags = .{},
    colorAttachment: u32 = 0,
    clearValue: ClearValue,
};
pub const ImageBlit = extern struct {
    srcSubresource: ImageSubresourceLayers = .{},
    srcOffsets: [2]Offset3D = @splat(.{}),
    dstSubresource: ImageSubresourceLayers = .{},
    dstOffsets: [2]Offset3D = @splat(.{}),
};
pub const ImageResolve = extern struct {
    srcSubresource: ImageSubresourceLayers = .{},
    srcOffset: Offset3D = .{},
    dstSubresource: ImageSubresourceLayers = .{},
    dstOffset: Offset3D = .{},
    extent: Extent3D = .{},
};
pub const RenderPassBeginInfo = extern struct {
    sType: StructureType = .render_pass_begin_info,
    pNext: ?*const anyopaque = null,
    renderPass: RenderPass = undefined,
    framebuffer: Framebuffer = undefined,
    renderArea: Rect2D = .{},
    clearValueCount: u32 = 0,
    pClearValues: [*]const ClearValue,
};
pub const BindBufferMemoryInfo = extern struct {
    sType: StructureType = .bind_buffer_memory_info,
    pNext: ?*const anyopaque = null,
    buffer: Buffer = undefined,
    memory: DeviceMemory = undefined,
    memoryOffset: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const BindImageMemoryInfo = extern struct {
    sType: StructureType = .bind_image_memory_info,
    pNext: ?*const anyopaque = null,
    image: Image = undefined,
    memory: DeviceMemory = undefined,
    memoryOffset: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const MemoryDedicatedRequirements = extern struct {
    sType: StructureType = .memory_dedicated_requirements,
    pNext: ?*anyopaque = null,
    prefersDedicatedAllocation: Bool = .False,
    requiresDedicatedAllocation: Bool = .False,
};
pub const MemoryDedicatedAllocateInfo = extern struct {
    sType: StructureType = .memory_dedicated_allocate_info,
    pNext: ?*const anyopaque = null,
    image: ?Image = null,
    buffer: ?Buffer = null,
};
pub const MemoryAllocateFlagsInfo = extern struct {
    sType: StructureType = .memory_allocate_flags_info,
    pNext: ?*const anyopaque = null,
    flags: MemoryAllocateFlags = .{},
    deviceMask: u32 = 0,
};
pub const DeviceGroupCommandBufferBeginInfo = extern struct {
    sType: StructureType = .device_group_command_buffer_begin_info,
    pNext: ?*const anyopaque = null,
    deviceMask: u32 = 0,
};
pub const DeviceGroupSubmitInfo = extern struct {
    sType: StructureType = .device_group_submit_info,
    pNext: ?*const anyopaque = null,
    waitSemaphoreCount: u32 = 0,
    pWaitSemaphoreDeviceIndices: [*]const u32 = undefined,
    commandBufferCount: u32 = 0,
    pCommandBufferDeviceMasks: [*]const u32 = undefined,
    signalSemaphoreCount: u32 = 0,
    pSignalSemaphoreDeviceIndices: [*]const u32 = undefined,
};
pub const DeviceGroupBindSparseInfo = extern struct {
    sType: StructureType = .device_group_bind_sparse_info,
    pNext: ?*const anyopaque = null,
    resourceDeviceIndex: u32 = 0,
    memoryDeviceIndex: u32 = 0,
};
pub const BindBufferMemoryDeviceGroupInfo = extern struct {
    sType: StructureType = .bind_buffer_memory_device_group_info,
    pNext: ?*const anyopaque = null,
    deviceIndexCount: u32 = 0,
    pDeviceIndices: [*]const u32 = undefined,
};
pub const BindImageMemoryDeviceGroupInfo = extern struct {
    sType: StructureType = .bind_image_memory_device_group_info,
    pNext: ?*const anyopaque = null,
    deviceIndexCount: u32 = 0,
    pDeviceIndices: [*]const u32 = undefined,
    splitInstanceBindRegionCount: u32 = 0,
    pSplitInstanceBindRegions: [*]const Rect2D = undefined,
};
pub const PhysicalDeviceGroupProperties = extern struct {
    sType: StructureType = .physical_device_group_properties,
    pNext: ?*anyopaque = null,
    physicalDeviceCount: u32 = 0,
    physicalDevices: [MaxDeviceGroupSize]PhysicalDevice = undefined,
    subsetAllocation: Bool = .False,
};
pub const DeviceGroupDeviceCreateInfo = extern struct {
    sType: StructureType = .device_group_device_create_info,
    pNext: ?*const anyopaque = null,
    physicalDeviceCount: u32 = 0,
    pPhysicalDevices: [*]const PhysicalDevice = undefined,
};
pub const BufferMemoryRequirementsInfo2 = extern struct {
    sType: StructureType = .buffer_memory_requirements_info_2,
    pNext: ?*const anyopaque = null,
    buffer: Buffer = undefined,
};
pub const ImageMemoryRequirementsInfo2 = extern struct {
    sType: StructureType = .image_memory_requirements_info_2,
    pNext: ?*const anyopaque = null,
    image: Image = undefined,
};
pub const ImageSparseMemoryRequirementsInfo2 = extern struct {
    sType: StructureType = .image_sparse_memory_requirements_info_2,
    pNext: ?*const anyopaque = null,
    image: Image = undefined,
};
pub const MemoryRequirements2 = extern struct {
    sType: StructureType = .memory_requirements_2,
    pNext: ?*anyopaque = null,
    memoryRequirements: MemoryRequirements = .{},
};
pub const SparseImageMemoryRequirements2 = extern struct {
    sType: StructureType = .sparse_image_memory_requirements_2,
    pNext: ?*anyopaque = null,
    memoryRequirements: SparseImageMemoryRequirements = .{},
};
pub const PhysicalDeviceFeatures2 = extern struct {
    sType: StructureType = .physical_device_features_2,
    pNext: ?*anyopaque = null,
    features: PhysicalDeviceFeatures = .{},
};
pub const PhysicalDeviceProperties2 = extern struct {
    sType: StructureType = .physical_device_properties_2,
    pNext: ?*anyopaque = null,
    properties: PhysicalDeviceProperties = .{},
};
pub const FormatProperties2 = extern struct {
    sType: StructureType = .format_properties_2,
    pNext: ?*anyopaque = null,
    formatProperties: FormatProperties = .{},
};
pub const ImageFormatProperties2 = extern struct {
    sType: StructureType = .image_format_properties_2,
    pNext: ?*anyopaque = null,
    imageFormatProperties: ImageFormatProperties = .{},
};
pub const PhysicalDeviceImageFormatInfo2 = extern struct {
    sType: StructureType = .physical_device_image_format_info_2,
    pNext: ?*const anyopaque = null,
    format: Format = .undefined,
    type: ImageType = .@"1d",
    tiling: ImageTiling = .optimal,
    usage: ImageUsageFlags = .{},
    flags: ImageCreateFlags = .{},
};
pub const QueueFamilyProperties2 = extern struct {
    sType: StructureType = .queue_family_properties_2,
    pNext: ?*anyopaque = null,
    queueFamilyProperties: QueueFamilyProperties = .{},
};
pub const PhysicalDeviceMemoryProperties2 = extern struct {
    sType: StructureType = .physical_device_memory_properties_2,
    pNext: ?*anyopaque = null,
    memoryProperties: PhysicalDeviceMemoryProperties = .{},
};
pub const SparseImageFormatProperties2 = extern struct {
    sType: StructureType = .sparse_image_format_properties_2,
    pNext: ?*anyopaque = null,
    properties: SparseImageFormatProperties = .{},
};
pub const PhysicalDeviceSparseImageFormatInfo2 = extern struct {
    sType: StructureType = .physical_device_sparse_image_format_info_2,
    pNext: ?*const anyopaque = null,
    format: Format = .undefined,
    type: ImageType = .@"1d",
    samples: SampleCountFlags = std.mem.zeroes(SampleCountFlags),
    usage: ImageUsageFlags = .{},
    tiling: ImageTiling = .optimal,
};
pub const ImageViewUsageCreateInfo = extern struct {
    sType: StructureType = .image_view_usage_create_info,
    pNext: ?*const anyopaque = null,
    usage: ImageUsageFlags = .{},
};
pub const PhysicalDeviceProtectedMemoryFeatures = extern struct {
    sType: StructureType = .physical_device_protected_memory_features,
    pNext: ?*anyopaque = null,
    protectedMemory: Bool = .False,
};
pub const PhysicalDeviceProtectedMemoryProperties = extern struct {
    sType: StructureType = .physical_device_protected_memory_properties,
    pNext: ?*anyopaque = null,
    protectedNoFault: Bool = .False,
};
pub const DeviceQueueInfo2 = extern struct {
    sType: StructureType = .device_queue_info_2,
    pNext: ?*const anyopaque = null,
    flags: DeviceQueueCreateFlags = .{},
    queueFamilyIndex: u32 = 0,
    queueIndex: u32 = 0,
};
pub const ProtectedSubmitInfo = extern struct {
    sType: StructureType = .protected_submit_info,
    pNext: ?*const anyopaque = null,
    protectedSubmit: Bool = .False,
};
pub const BindImagePlaneMemoryInfo = extern struct {
    sType: StructureType = .bind_image_plane_memory_info,
    pNext: ?*const anyopaque = null,
    planeAspect: ImageAspectFlags = std.mem.zeroes(ImageAspectFlags),
};
pub const ImagePlaneMemoryRequirementsInfo = extern struct {
    sType: StructureType = .image_plane_memory_requirements_info,
    pNext: ?*const anyopaque = null,
    planeAspect: ImageAspectFlags = std.mem.zeroes(ImageAspectFlags),
};
pub const ExternalMemoryProperties = extern struct {
    externalMemoryFeatures: ExternalMemoryFeatureFlags = .{},
    exportFromImportedHandleTypes: ExternalMemoryHandleTypeFlags = .{},
    compatibleHandleTypes: ExternalMemoryHandleTypeFlags = .{},
};
pub const PhysicalDeviceExternalImageFormatInfo = extern struct {
    sType: StructureType = .physical_device_external_image_format_info,
    pNext: ?*const anyopaque = null,
    handleType: ExternalMemoryHandleTypeFlags = std.mem.zeroes(ExternalMemoryHandleTypeFlags),
};
pub const ExternalImageFormatProperties = extern struct {
    sType: StructureType = .external_image_format_properties,
    pNext: ?*anyopaque = null,
    externalMemoryProperties: ExternalMemoryProperties = .{},
};
pub const PhysicalDeviceExternalBufferInfo = extern struct {
    sType: StructureType = .physical_device_external_buffer_info,
    pNext: ?*const anyopaque = null,
    flags: BufferCreateFlags = .{},
    usage: BufferUsageFlags = .{},
    handleType: ExternalMemoryHandleTypeFlags = std.mem.zeroes(ExternalMemoryHandleTypeFlags),
};
pub const ExternalBufferProperties = extern struct {
    sType: StructureType = .external_buffer_properties,
    pNext: ?*anyopaque = null,
    externalMemoryProperties: ExternalMemoryProperties = .{},
};
pub const PhysicalDeviceIDProperties = extern struct {
    sType: StructureType = .physical_device_id_properties,
    pNext: ?*anyopaque = null,
    deviceUUID: [UuidSize]u8 = @splat(0),
    driverUUID: [UuidSize]u8 = @splat(0),
    deviceLUID: [LuidSize]u8 = @splat(0),
    deviceNodeMask: u32 = 0,
    deviceLUIDValid: Bool = .False,
};
pub const ExternalMemoryImageCreateInfo = extern struct {
    sType: StructureType = .external_memory_image_create_info,
    pNext: ?*const anyopaque = null,
    handleTypes: ExternalMemoryHandleTypeFlags = .{},
};
pub const ExternalMemoryBufferCreateInfo = extern struct {
    sType: StructureType = .external_memory_buffer_create_info,
    pNext: ?*const anyopaque = null,
    handleTypes: ExternalMemoryHandleTypeFlags = .{},
};
pub const ExportMemoryAllocateInfo = extern struct {
    sType: StructureType = .export_memory_allocate_info,
    pNext: ?*const anyopaque = null,
    handleTypes: ExternalMemoryHandleTypeFlags = .{},
};
pub const PhysicalDeviceExternalFenceInfo = extern struct {
    sType: StructureType = .physical_device_external_fence_info,
    pNext: ?*const anyopaque = null,
    handleType: ExternalFenceHandleTypeFlags = std.mem.zeroes(ExternalFenceHandleTypeFlags),
};
pub const ExternalFenceProperties = extern struct {
    sType: StructureType = .external_fence_properties,
    pNext: ?*anyopaque = null,
    exportFromImportedHandleTypes: ExternalFenceHandleTypeFlags = .{},
    compatibleHandleTypes: ExternalFenceHandleTypeFlags = .{},
    externalFenceFeatures: ExternalFenceFeatureFlags = .{},
};
pub const ExportFenceCreateInfo = extern struct {
    sType: StructureType = .export_fence_create_info,
    pNext: ?*const anyopaque = null,
    handleTypes: ExternalFenceHandleTypeFlags = .{},
};
pub const ExportSemaphoreCreateInfo = extern struct {
    sType: StructureType = .export_semaphore_create_info,
    pNext: ?*const anyopaque = null,
    handleTypes: ExternalSemaphoreHandleTypeFlags = .{},
};
pub const PhysicalDeviceExternalSemaphoreInfo = extern struct {
    sType: StructureType = .physical_device_external_semaphore_info,
    pNext: ?*const anyopaque = null,
    handleType: ExternalSemaphoreHandleTypeFlags = std.mem.zeroes(ExternalSemaphoreHandleTypeFlags),
};
pub const ExternalSemaphoreProperties = extern struct {
    sType: StructureType = .external_semaphore_properties,
    pNext: ?*anyopaque = null,
    exportFromImportedHandleTypes: ExternalSemaphoreHandleTypeFlags = .{},
    compatibleHandleTypes: ExternalSemaphoreHandleTypeFlags = .{},
    externalSemaphoreFeatures: ExternalSemaphoreFeatureFlags = .{},
};
pub const PhysicalDeviceSubgroupProperties = extern struct {
    sType: StructureType = .physical_device_subgroup_properties,
    pNext: ?*anyopaque = null,
    subgroupSize: u32 = 0,
    supportedStages: ShaderStageFlags = .{},
    supportedOperations: SubgroupFeatureFlags = .{},
    quadOperationsInAllStages: Bool = .False,
};
pub const PhysicalDevice16BitStorageFeatures = extern struct {
    sType: StructureType = .physical_device_16bit_storage_features,
    pNext: ?*anyopaque = null,
    storageBuffer16BitAccess: Bool = .False,
    uniformAndStorageBuffer16BitAccess: Bool = .False,
    storagePushConstant16: Bool = .False,
    storageInputOutput16: Bool = .False,
};
pub const PhysicalDeviceVariablePointersFeatures = extern struct {
    sType: StructureType = .physical_device_variable_pointers_features,
    pNext: ?*anyopaque = null,
    variablePointersStorageBuffer: Bool = .False,
    variablePointers: Bool = .False,
};
pub const DescriptorUpdateTemplateEntry = extern struct {
    dstBinding: u32 = 0,
    dstArrayElement: u32 = 0,
    descriptorCount: u32 = 0,
    descriptorType: DescriptorType = .sampler,
    offset: u64 = std.mem.zeroes(u64),
    stride: u64 = std.mem.zeroes(u64),
};
pub const DescriptorUpdateTemplateCreateInfo = extern struct {
    sType: StructureType = .descriptor_update_template_create_info,
    pNext: ?*const anyopaque = null,
    flags: DescriptorUpdateTemplateCreateFlags = std.mem.zeroes(DescriptorUpdateTemplateCreateFlags),
    descriptorUpdateEntryCount: u32 = 0,
    pDescriptorUpdateEntries: [*]const DescriptorUpdateTemplateEntry = undefined,
    templateType: DescriptorUpdateTemplateType = .descriptor_set,
    descriptorSetLayout: DescriptorSetLayout = undefined,
    pipelineBindPoint: PipelineBindPoint = .graphics,
    pipelineLayout: PipelineLayout = undefined,
    set: u32 = 0,
};
pub const PhysicalDeviceMaintenance3Properties = extern struct {
    sType: StructureType = .physical_device_maintenance_3_properties,
    pNext: ?*anyopaque = null,
    maxPerSetDescriptors: u32 = 0,
    maxMemoryAllocationSize: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const DescriptorSetLayoutSupport = extern struct {
    sType: StructureType = .descriptor_set_layout_support,
    pNext: ?*anyopaque = null,
    supported: Bool = .False,
};
pub const SamplerYcbcrConversionCreateInfo = extern struct {
    sType: StructureType = .sampler_ycbcr_conversion_create_info,
    pNext: ?*const anyopaque = null,
    format: Format = .undefined,
    ycbcrModel: SamplerYcbcrModelConversion = .rgb_identity,
    ycbcrRange: SamplerYcbcrRange = .itu_full,
    components: ComponentMapping = .{},
    xChromaOffset: ChromaLocation = .cosited_even,
    yChromaOffset: ChromaLocation = .cosited_even,
    chromaFilter: Filter = .nearest,
    forceExplicitReconstruction: Bool = .False,
};
pub const SamplerYcbcrConversionInfo = extern struct {
    sType: StructureType = .sampler_ycbcr_conversion_info,
    pNext: ?*const anyopaque = null,
    conversion: SamplerYcbcrConversion = undefined,
};
pub const PhysicalDeviceSamplerYcbcrConversionFeatures = extern struct {
    sType: StructureType = .physical_device_sampler_ycbcr_conversion_features,
    pNext: ?*anyopaque = null,
    samplerYcbcrConversion: Bool = .False,
};
pub const SamplerYcbcrConversionImageFormatProperties = extern struct {
    sType: StructureType = .sampler_ycbcr_conversion_image_format_properties,
    pNext: ?*anyopaque = null,
    combinedImageSamplerDescriptorCount: u32 = 0,
};
pub const DeviceGroupRenderPassBeginInfo = extern struct {
    sType: StructureType = .device_group_render_pass_begin_info,
    pNext: ?*const anyopaque = null,
    deviceMask: u32 = 0,
    deviceRenderAreaCount: u32 = 0,
    pDeviceRenderAreas: [*]const Rect2D = undefined,
};
pub const PhysicalDevicePointClippingProperties = extern struct {
    sType: StructureType = .physical_device_point_clipping_properties,
    pNext: ?*anyopaque = null,
    pointClippingBehavior: PointClippingBehavior = .all_clip_planes,
};
pub const InputAttachmentAspectReference = extern struct {
    subpass: u32 = 0,
    inputAttachmentIndex: u32 = 0,
    aspectMask: ImageAspectFlags = .{},
};
pub const RenderPassInputAttachmentAspectCreateInfo = extern struct {
    sType: StructureType = .render_pass_input_attachment_aspect_create_info,
    pNext: ?*const anyopaque = null,
    aspectReferenceCount: u32 = 0,
    pAspectReferences: [*]const InputAttachmentAspectReference = undefined,
};
pub const PipelineTessellationDomainOriginStateCreateInfo = extern struct {
    sType: StructureType = .pipeline_tessellation_domain_origin_state_create_info,
    pNext: ?*const anyopaque = null,
    domainOrigin: TessellationDomainOrigin = .upper_left,
};
pub const RenderPassMultiviewCreateInfo = extern struct {
    sType: StructureType = .render_pass_multiview_create_info,
    pNext: ?*const anyopaque = null,
    subpassCount: u32 = 0,
    pViewMasks: [*]const u32 = undefined,
    dependencyCount: u32 = 0,
    pViewOffsets: [*]const i32 = undefined,
    correlationMaskCount: u32 = 0,
    pCorrelationMasks: [*]const u32 = undefined,
};
pub const PhysicalDeviceMultiviewFeatures = extern struct {
    sType: StructureType = .physical_device_multiview_features,
    pNext: ?*anyopaque = null,
    multiview: Bool = .False,
    multiviewGeometryShader: Bool = .False,
    multiviewTessellationShader: Bool = .False,
};
pub const PhysicalDeviceMultiviewProperties = extern struct {
    sType: StructureType = .physical_device_multiview_properties,
    pNext: ?*anyopaque = null,
    maxMultiviewViewCount: u32 = 0,
    maxMultiviewInstanceIndex: u32 = 0,
};
pub const PhysicalDeviceShaderDrawParametersFeatures = extern struct {
    sType: StructureType = .physical_device_shader_draw_parameters_features,
    pNext: ?*anyopaque = null,
    shaderDrawParameters: Bool = .False,
};
pub const ConformanceVersion = extern struct {
    major: u8 = 0,
    minor: u8 = 0,
    subminor: u8 = 0,
    patch: u8 = 0,
};
pub const PhysicalDeviceDriverProperties = extern struct {
    sType: StructureType = .physical_device_driver_properties,
    pNext: ?*anyopaque = null,
    driverID: DriverId,
    driverName: [MaxDriverNameSize]u8 = @splat(0),
    driverInfo: [MaxDriverInfoSize]u8 = @splat(0),
    conformanceVersion: ConformanceVersion = .{},
};
pub const PhysicalDeviceVulkan11Features = extern struct {
    sType: StructureType = .physical_device_vulkan_1_1_features,
    pNext: ?*anyopaque = null,
    storageBuffer16BitAccess: Bool = .False,
    uniformAndStorageBuffer16BitAccess: Bool = .False,
    storagePushConstant16: Bool = .False,
    storageInputOutput16: Bool = .False,
    multiview: Bool = .False,
    multiviewGeometryShader: Bool = .False,
    multiviewTessellationShader: Bool = .False,
    variablePointersStorageBuffer: Bool = .False,
    variablePointers: Bool = .False,
    protectedMemory: Bool = .False,
    samplerYcbcrConversion: Bool = .False,
    shaderDrawParameters: Bool = .False,
};
pub const PhysicalDeviceVulkan11Properties = extern struct {
    sType: StructureType = .physical_device_vulkan_1_1_properties,
    pNext: ?*anyopaque = null,
    deviceUUID: [UuidSize]u8 = @splat(0),
    driverUUID: [UuidSize]u8 = @splat(0),
    deviceLUID: [LuidSize]u8 = @splat(0),
    deviceNodeMask: u32 = 0,
    deviceLUIDValid: Bool = .False,
    subgroupSize: u32 = 0,
    subgroupSupportedStages: ShaderStageFlags = .{},
    subgroupSupportedOperations: SubgroupFeatureFlags = .{},
    subgroupQuadOperationsInAllStages: Bool = .False,
    pointClippingBehavior: PointClippingBehavior = .all_clip_planes,
    maxMultiviewViewCount: u32 = 0,
    maxMultiviewInstanceIndex: u32 = 0,
    protectedNoFault: Bool = .False,
    maxPerSetDescriptors: u32 = 0,
    maxMemoryAllocationSize: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const PhysicalDeviceVulkan12Features = extern struct {
    sType: StructureType = .physical_device_vulkan_1_2_features,
    pNext: ?*anyopaque = null,
    samplerMirrorClampToEdge: Bool = .False,
    drawIndirectCount: Bool = .False,
    storageBuffer8BitAccess: Bool = .False,
    uniformAndStorageBuffer8BitAccess: Bool = .False,
    storagePushConstant8: Bool = .False,
    shaderBufferInt64Atomics: Bool = .False,
    shaderSharedInt64Atomics: Bool = .False,
    shaderFloat16: Bool = .False,
    shaderInt8: Bool = .False,
    descriptorIndexing: Bool = .False,
    shaderInputAttachmentArrayDynamicIndexing: Bool = .False,
    shaderUniformTexelBufferArrayDynamicIndexing: Bool = .False,
    shaderStorageTexelBufferArrayDynamicIndexing: Bool = .False,
    shaderUniformBufferArrayNonUniformIndexing: Bool = .False,
    shaderSampledImageArrayNonUniformIndexing: Bool = .False,
    shaderStorageBufferArrayNonUniformIndexing: Bool = .False,
    shaderStorageImageArrayNonUniformIndexing: Bool = .False,
    shaderInputAttachmentArrayNonUniformIndexing: Bool = .False,
    shaderUniformTexelBufferArrayNonUniformIndexing: Bool = .False,
    shaderStorageTexelBufferArrayNonUniformIndexing: Bool = .False,
    descriptorBindingUniformBufferUpdateAfterBind: Bool = .False,
    descriptorBindingSampledImageUpdateAfterBind: Bool = .False,
    descriptorBindingStorageImageUpdateAfterBind: Bool = .False,
    descriptorBindingStorageBufferUpdateAfterBind: Bool = .False,
    descriptorBindingUniformTexelBufferUpdateAfterBind: Bool = .False,
    descriptorBindingStorageTexelBufferUpdateAfterBind: Bool = .False,
    descriptorBindingUpdateUnusedWhilePending: Bool = .False,
    descriptorBindingPartiallyBound: Bool = .False,
    descriptorBindingVariableDescriptorCount: Bool = .False,
    runtimeDescriptorArray: Bool = .False,
    samplerFilterMinmax: Bool = .False,
    scalarBlockLayout: Bool = .False,
    imagelessFramebuffer: Bool = .False,
    uniformBufferStandardLayout: Bool = .False,
    shaderSubgroupExtendedTypes: Bool = .False,
    separateDepthStencilLayouts: Bool = .False,
    hostQueryReset: Bool = .False,
    timelineSemaphore: Bool = .False,
    bufferDeviceAddress: Bool = .False,
    bufferDeviceAddressCaptureReplay: Bool = .False,
    bufferDeviceAddressMultiDevice: Bool = .False,
    vulkanMemoryModel: Bool = .False,
    vulkanMemoryModelDeviceScope: Bool = .False,
    vulkanMemoryModelAvailabilityVisibilityChains: Bool = .False,
    shaderOutputViewportIndex: Bool = .False,
    shaderOutputLayer: Bool = .False,
    subgroupBroadcastDynamicId: Bool = .False,
};
pub const PhysicalDeviceVulkan12Properties = extern struct {
    sType: StructureType = .physical_device_vulkan_1_2_properties,
    pNext: ?*anyopaque = null,
    driverID: DriverId,
    driverName: [MaxDriverNameSize]u8 = @splat(0),
    driverInfo: [MaxDriverInfoSize]u8 = @splat(0),
    conformanceVersion: ConformanceVersion = .{},
    denormBehaviorIndependence: ShaderFloatControlsIndependence = .@"32_only",
    roundingModeIndependence: ShaderFloatControlsIndependence = .@"32_only",
    shaderSignedZeroInfNanPreserveFloat16: Bool = .False,
    shaderSignedZeroInfNanPreserveFloat32: Bool = .False,
    shaderSignedZeroInfNanPreserveFloat64: Bool = .False,
    shaderDenormPreserveFloat16: Bool = .False,
    shaderDenormPreserveFloat32: Bool = .False,
    shaderDenormPreserveFloat64: Bool = .False,
    shaderDenormFlushToZeroFloat16: Bool = .False,
    shaderDenormFlushToZeroFloat32: Bool = .False,
    shaderDenormFlushToZeroFloat64: Bool = .False,
    shaderRoundingModeRTEFloat16: Bool = .False,
    shaderRoundingModeRTEFloat32: Bool = .False,
    shaderRoundingModeRTEFloat64: Bool = .False,
    shaderRoundingModeRTZFloat16: Bool = .False,
    shaderRoundingModeRTZFloat32: Bool = .False,
    shaderRoundingModeRTZFloat64: Bool = .False,
    maxUpdateAfterBindDescriptorsInAllPools: u32 = 0,
    shaderUniformBufferArrayNonUniformIndexingNative: Bool = .False,
    shaderSampledImageArrayNonUniformIndexingNative: Bool = .False,
    shaderStorageBufferArrayNonUniformIndexingNative: Bool = .False,
    shaderStorageImageArrayNonUniformIndexingNative: Bool = .False,
    shaderInputAttachmentArrayNonUniformIndexingNative: Bool = .False,
    robustBufferAccessUpdateAfterBind: Bool = .False,
    quadDivergentImplicitLod: Bool = .False,
    maxPerStageDescriptorUpdateAfterBindSamplers: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindUniformBuffers: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindStorageBuffers: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindSampledImages: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindStorageImages: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindInputAttachments: u32 = 0,
    maxPerStageUpdateAfterBindResources: u32 = 0,
    maxDescriptorSetUpdateAfterBindSamplers: u32 = 0,
    maxDescriptorSetUpdateAfterBindUniformBuffers: u32 = 0,
    maxDescriptorSetUpdateAfterBindUniformBuffersDynamic: u32 = 0,
    maxDescriptorSetUpdateAfterBindStorageBuffers: u32 = 0,
    maxDescriptorSetUpdateAfterBindStorageBuffersDynamic: u32 = 0,
    maxDescriptorSetUpdateAfterBindSampledImages: u32 = 0,
    maxDescriptorSetUpdateAfterBindStorageImages: u32 = 0,
    maxDescriptorSetUpdateAfterBindInputAttachments: u32 = 0,
    supportedDepthResolveModes: ResolveModeFlags = .{},
    supportedStencilResolveModes: ResolveModeFlags = .{},
    independentResolveNone: Bool = .False,
    independentResolve: Bool = .False,
    filterMinmaxSingleComponentFormats: Bool = .False,
    filterMinmaxImageComponentMapping: Bool = .False,
    maxTimelineSemaphoreValueDifference: u64 = 0,
    framebufferIntegerColorSampleCounts: SampleCountFlags = .{},
};
pub const ImageFormatListCreateInfo = extern struct {
    sType: StructureType = .image_format_list_create_info,
    pNext: ?*const anyopaque = null,
    viewFormatCount: u32 = 0,
    pViewFormats: [*]const Format = undefined,
};
pub const PhysicalDeviceVulkanMemoryModelFeatures = extern struct {
    sType: StructureType = .physical_device_vulkan_memory_model_features,
    pNext: ?*anyopaque = null,
    vulkanMemoryModel: Bool = .False,
    vulkanMemoryModelDeviceScope: Bool = .False,
    vulkanMemoryModelAvailabilityVisibilityChains: Bool = .False,
};
pub const PhysicalDeviceHostQueryResetFeatures = extern struct {
    sType: StructureType = .physical_device_host_query_reset_features,
    pNext: ?*anyopaque = null,
    hostQueryReset: Bool = .False,
};
pub const PhysicalDeviceTimelineSemaphoreFeatures = extern struct {
    sType: StructureType = .physical_device_timeline_semaphore_features,
    pNext: ?*anyopaque = null,
    timelineSemaphore: Bool = .False,
};
pub const PhysicalDeviceTimelineSemaphoreProperties = extern struct {
    sType: StructureType = .physical_device_timeline_semaphore_properties,
    pNext: ?*anyopaque = null,
    maxTimelineSemaphoreValueDifference: u64 = 0,
};
pub const SemaphoreTypeCreateInfo = extern struct {
    sType: StructureType = .semaphore_type_create_info,
    pNext: ?*const anyopaque = null,
    semaphoreType: SemaphoreType = .binary,
    initialValue: u64 = 0,
};
pub const TimelineSemaphoreSubmitInfo = extern struct {
    sType: StructureType = .timeline_semaphore_submit_info,
    pNext: ?*const anyopaque = null,
    waitSemaphoreValueCount: u32 = 0,
    pWaitSemaphoreValues: ?[*]const u64 = null,
    signalSemaphoreValueCount: u32 = 0,
    pSignalSemaphoreValues: ?[*]const u64 = null,
};
pub const SemaphoreWaitInfo = extern struct {
    sType: StructureType = .semaphore_wait_info,
    pNext: ?*const anyopaque = null,
    flags: SemaphoreWaitFlags = .{},
    semaphoreCount: u32 = 0,
    pSemaphores: [*]const Semaphore = undefined,
    pValues: [*]const u64 = undefined,
};
pub const SemaphoreSignalInfo = extern struct {
    sType: StructureType = .semaphore_signal_info,
    pNext: ?*const anyopaque = null,
    semaphore: Semaphore = undefined,
    value: u64 = 0,
};
pub const PhysicalDeviceBufferDeviceAddressFeatures = extern struct {
    sType: StructureType = .physical_device_buffer_device_address_features,
    pNext: ?*anyopaque = null,
    bufferDeviceAddress: Bool = .False,
    bufferDeviceAddressCaptureReplay: Bool = .False,
    bufferDeviceAddressMultiDevice: Bool = .False,
};
pub const BufferDeviceAddressInfo = extern struct {
    sType: StructureType = .buffer_device_address_info,
    pNext: ?*const anyopaque = null,
    buffer: Buffer = undefined,
};
pub const BufferOpaqueCaptureAddressCreateInfo = extern struct {
    sType: StructureType = .buffer_opaque_capture_address_create_info,
    pNext: ?*const anyopaque = null,
    opaqueCaptureAddress: u64 = 0,
};
pub const MemoryOpaqueCaptureAddressAllocateInfo = extern struct {
    sType: StructureType = .memory_opaque_capture_address_allocate_info,
    pNext: ?*const anyopaque = null,
    opaqueCaptureAddress: u64 = 0,
};
pub const DeviceMemoryOpaqueCaptureAddressInfo = extern struct {
    sType: StructureType = .device_memory_opaque_capture_address_info,
    pNext: ?*const anyopaque = null,
    memory: DeviceMemory = undefined,
};
pub const PhysicalDevice8BitStorageFeatures = extern struct {
    sType: StructureType = .physical_device_8bit_storage_features,
    pNext: ?*anyopaque = null,
    storageBuffer8BitAccess: Bool = .False,
    uniformAndStorageBuffer8BitAccess: Bool = .False,
    storagePushConstant8: Bool = .False,
};
pub const PhysicalDeviceShaderAtomicInt64Features = extern struct {
    sType: StructureType = .physical_device_shader_atomic_int64_features,
    pNext: ?*anyopaque = null,
    shaderBufferInt64Atomics: Bool = .False,
    shaderSharedInt64Atomics: Bool = .False,
};
pub const PhysicalDeviceShaderFloat16Int8Features = extern struct {
    sType: StructureType = .physical_device_shader_float16_int8_features,
    pNext: ?*anyopaque = null,
    shaderFloat16: Bool = .False,
    shaderInt8: Bool = .False,
};
pub const PhysicalDeviceFloatControlsProperties = extern struct {
    sType: StructureType = .physical_device_float_controls_properties,
    pNext: ?*anyopaque = null,
    denormBehaviorIndependence: ShaderFloatControlsIndependence = .@"32_only",
    roundingModeIndependence: ShaderFloatControlsIndependence = .@"32_only",
    shaderSignedZeroInfNanPreserveFloat16: Bool = .False,
    shaderSignedZeroInfNanPreserveFloat32: Bool = .False,
    shaderSignedZeroInfNanPreserveFloat64: Bool = .False,
    shaderDenormPreserveFloat16: Bool = .False,
    shaderDenormPreserveFloat32: Bool = .False,
    shaderDenormPreserveFloat64: Bool = .False,
    shaderDenormFlushToZeroFloat16: Bool = .False,
    shaderDenormFlushToZeroFloat32: Bool = .False,
    shaderDenormFlushToZeroFloat64: Bool = .False,
    shaderRoundingModeRTEFloat16: Bool = .False,
    shaderRoundingModeRTEFloat32: Bool = .False,
    shaderRoundingModeRTEFloat64: Bool = .False,
    shaderRoundingModeRTZFloat16: Bool = .False,
    shaderRoundingModeRTZFloat32: Bool = .False,
    shaderRoundingModeRTZFloat64: Bool = .False,
};
pub const DescriptorSetLayoutBindingFlagsCreateInfo = extern struct {
    sType: StructureType = .descriptor_set_layout_binding_flags_create_info,
    pNext: ?*const anyopaque = null,
    bindingCount: u32 = 0,
    pBindingFlags: ?[*]const DescriptorBindingFlags = undefined,
};
pub const PhysicalDeviceDescriptorIndexingFeatures = extern struct {
    sType: StructureType = .physical_device_descriptor_indexing_features,
    pNext: ?*anyopaque = null,
    shaderInputAttachmentArrayDynamicIndexing: Bool = .False,
    shaderUniformTexelBufferArrayDynamicIndexing: Bool = .False,
    shaderStorageTexelBufferArrayDynamicIndexing: Bool = .False,
    shaderUniformBufferArrayNonUniformIndexing: Bool = .False,
    shaderSampledImageArrayNonUniformIndexing: Bool = .False,
    shaderStorageBufferArrayNonUniformIndexing: Bool = .False,
    shaderStorageImageArrayNonUniformIndexing: Bool = .False,
    shaderInputAttachmentArrayNonUniformIndexing: Bool = .False,
    shaderUniformTexelBufferArrayNonUniformIndexing: Bool = .False,
    shaderStorageTexelBufferArrayNonUniformIndexing: Bool = .False,
    descriptorBindingUniformBufferUpdateAfterBind: Bool = .False,
    descriptorBindingSampledImageUpdateAfterBind: Bool = .False,
    descriptorBindingStorageImageUpdateAfterBind: Bool = .False,
    descriptorBindingStorageBufferUpdateAfterBind: Bool = .False,
    descriptorBindingUniformTexelBufferUpdateAfterBind: Bool = .False,
    descriptorBindingStorageTexelBufferUpdateAfterBind: Bool = .False,
    descriptorBindingUpdateUnusedWhilePending: Bool = .False,
    descriptorBindingPartiallyBound: Bool = .False,
    descriptorBindingVariableDescriptorCount: Bool = .False,
    runtimeDescriptorArray: Bool = .False,
};
pub const PhysicalDeviceDescriptorIndexingProperties = extern struct {
    sType: StructureType = .physical_device_descriptor_indexing_properties,
    pNext: ?*anyopaque = null,
    maxUpdateAfterBindDescriptorsInAllPools: u32 = 0,
    shaderUniformBufferArrayNonUniformIndexingNative: Bool = .False,
    shaderSampledImageArrayNonUniformIndexingNative: Bool = .False,
    shaderStorageBufferArrayNonUniformIndexingNative: Bool = .False,
    shaderStorageImageArrayNonUniformIndexingNative: Bool = .False,
    shaderInputAttachmentArrayNonUniformIndexingNative: Bool = .False,
    robustBufferAccessUpdateAfterBind: Bool = .False,
    quadDivergentImplicitLod: Bool = .False,
    maxPerStageDescriptorUpdateAfterBindSamplers: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindUniformBuffers: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindStorageBuffers: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindSampledImages: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindStorageImages: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindInputAttachments: u32 = 0,
    maxPerStageUpdateAfterBindResources: u32 = 0,
    maxDescriptorSetUpdateAfterBindSamplers: u32 = 0,
    maxDescriptorSetUpdateAfterBindUniformBuffers: u32 = 0,
    maxDescriptorSetUpdateAfterBindUniformBuffersDynamic: u32 = 0,
    maxDescriptorSetUpdateAfterBindStorageBuffers: u32 = 0,
    maxDescriptorSetUpdateAfterBindStorageBuffersDynamic: u32 = 0,
    maxDescriptorSetUpdateAfterBindSampledImages: u32 = 0,
    maxDescriptorSetUpdateAfterBindStorageImages: u32 = 0,
    maxDescriptorSetUpdateAfterBindInputAttachments: u32 = 0,
};
pub const DescriptorSetVariableDescriptorCountAllocateInfo = extern struct {
    sType: StructureType = .descriptor_set_variable_descriptor_count_allocate_info,
    pNext: ?*const anyopaque = null,
    descriptorSetCount: u32 = 0,
    pDescriptorCounts: [*]const u32 = undefined,
};
pub const DescriptorSetVariableDescriptorCountLayoutSupport = extern struct {
    sType: StructureType = .descriptor_set_variable_descriptor_count_layout_support,
    pNext: ?*anyopaque = null,
    maxVariableDescriptorCount: u32 = 0,
};
pub const PhysicalDeviceScalarBlockLayoutFeatures = extern struct {
    sType: StructureType = .physical_device_scalar_block_layout_features,
    pNext: ?*anyopaque = null,
    scalarBlockLayout: Bool = .False,
};
pub const SamplerReductionModeCreateInfo = extern struct {
    sType: StructureType = .sampler_reduction_mode_create_info,
    pNext: ?*const anyopaque = null,
    reductionMode: SamplerReductionMode = .weighted_average,
};
pub const PhysicalDeviceSamplerFilterMinmaxProperties = extern struct {
    sType: StructureType = .physical_device_sampler_filter_minmax_properties,
    pNext: ?*anyopaque = null,
    filterMinmaxSingleComponentFormats: Bool = .False,
    filterMinmaxImageComponentMapping: Bool = .False,
};
pub const PhysicalDeviceUniformBufferStandardLayoutFeatures = extern struct {
    sType: StructureType = .physical_device_uniform_buffer_standard_layout_features,
    pNext: ?*anyopaque = null,
    uniformBufferStandardLayout: Bool = .False,
};
pub const PhysicalDeviceShaderSubgroupExtendedTypesFeatures = extern struct {
    sType: StructureType = .physical_device_shader_subgroup_extended_types_features,
    pNext: ?*anyopaque = null,
    shaderSubgroupExtendedTypes: Bool = .False,
};
pub const AttachmentDescription2 = extern struct {
    sType: StructureType = .attachment_description_2,
    pNext: ?*const anyopaque = null,
    flags: AttachmentDescriptionFlags = .{},
    format: Format = .undefined,
    samples: SampleCountFlags = std.mem.zeroes(SampleCountFlags),
    loadOp: AttachmentLoadOp = .load,
    storeOp: AttachmentStoreOp = .store,
    stencilLoadOp: AttachmentLoadOp = .load,
    stencilStoreOp: AttachmentStoreOp = .store,
    initialLayout: ImageLayout = .undefined,
    finalLayout: ImageLayout = .undefined,
};
pub const AttachmentReference2 = extern struct {
    sType: StructureType = .attachment_reference_2,
    pNext: ?*const anyopaque = null,
    attachment: u32 = 0,
    layout: ImageLayout = .undefined,
    aspectMask: ImageAspectFlags = .{},
};
pub const SubpassDescription2 = extern struct {
    sType: StructureType = .subpass_description_2,
    pNext: ?*const anyopaque = null,
    flags: SubpassDescriptionFlags = .{},
    pipelineBindPoint: PipelineBindPoint = .graphics,
    viewMask: u32 = 0,
    inputAttachmentCount: u32 = 0,
    pInputAttachments: [*]const AttachmentReference2 = undefined,
    colorAttachmentCount: u32 = 0,
    pColorAttachments: [*]const AttachmentReference2 = undefined,
    pResolveAttachments: ?[*]const AttachmentReference2 = null,
    pDepthStencilAttachment: ?*const AttachmentReference2 = null,
    preserveAttachmentCount: u32 = 0,
    pPreserveAttachments: [*]const u32 = undefined,
};
pub const SubpassDependency2 = extern struct {
    sType: StructureType = .subpass_dependency_2,
    pNext: ?*const anyopaque = null,
    srcSubpass: u32 = 0,
    dstSubpass: u32 = 0,
    srcStageMask: PipelineStageFlags = .{},
    dstStageMask: PipelineStageFlags = .{},
    srcAccessMask: AccessFlags = .{},
    dstAccessMask: AccessFlags = .{},
    dependencyFlags: DependencyFlags = .{},
    viewOffset: i32 = 0,
};
pub const SubpassBeginInfo = extern struct {
    sType: StructureType = .subpass_begin_info,
    pNext: ?*const anyopaque = null,
    contents: SubpassContents = .@"inline",
};
pub const SubpassEndInfo = extern struct {
    sType: StructureType = .subpass_end_info,
    pNext: ?*const anyopaque = null,
};
pub const RenderPassCreateInfo2 = extern struct {
    sType: StructureType = .render_pass_create_info_2,
    pNext: ?*const anyopaque = null,
    flags: RenderPassCreateFlags = .{},
    attachmentCount: u32 = 0,
    pAttachments: [*]const AttachmentDescription2 = undefined,
    subpassCount: u32 = 0,
    pSubpasses: [*]const SubpassDescription2 = undefined,
    dependencyCount: u32 = 0,
    pDependencies: [*]const SubpassDependency2 = undefined,
    correlatedViewMaskCount: u32 = 0,
    pCorrelatedViewMasks: [*]const u32 = undefined,
};
pub const SubpassDescriptionDepthStencilResolve = extern struct {
    sType: StructureType = .subpass_description_depth_stencil_resolve,
    pNext: ?*const anyopaque = null,
    depthResolveMode: ResolveModeFlags = std.mem.zeroes(ResolveModeFlags),
    stencilResolveMode: ResolveModeFlags = std.mem.zeroes(ResolveModeFlags),
    pDepthStencilResolveAttachment: ?*const AttachmentReference2 = null,
};
pub const PhysicalDeviceDepthStencilResolveProperties = extern struct {
    sType: StructureType = .physical_device_depth_stencil_resolve_properties,
    pNext: ?*anyopaque = null,
    supportedDepthResolveModes: ResolveModeFlags = .{},
    supportedStencilResolveModes: ResolveModeFlags = .{},
    independentResolveNone: Bool = .False,
    independentResolve: Bool = .False,
};
pub const ImageStencilUsageCreateInfo = extern struct {
    sType: StructureType = .image_stencil_usage_create_info,
    pNext: ?*const anyopaque = null,
    stencilUsage: ImageUsageFlags = .{},
};
pub const PhysicalDeviceImagelessFramebufferFeatures = extern struct {
    sType: StructureType = .physical_device_imageless_framebuffer_features,
    pNext: ?*anyopaque = null,
    imagelessFramebuffer: Bool = .False,
};
pub const FramebufferAttachmentImageInfo = extern struct {
    sType: StructureType = .framebuffer_attachment_image_info,
    pNext: ?*const anyopaque = null,
    flags: ImageCreateFlags = .{},
    usage: ImageUsageFlags = .{},
    width: u32 = 0,
    height: u32 = 0,
    layerCount: u32 = 0,
    viewFormatCount: u32 = 0,
    pViewFormats: [*]const Format = undefined,
};
pub const RenderPassAttachmentBeginInfo = extern struct {
    sType: StructureType = .render_pass_attachment_begin_info,
    pNext: ?*const anyopaque = null,
    attachmentCount: u32 = 0,
    pAttachments: [*]const ImageView = undefined,
};
pub const FramebufferAttachmentsCreateInfo = extern struct {
    sType: StructureType = .framebuffer_attachments_create_info,
    pNext: ?*const anyopaque = null,
    attachmentImageInfoCount: u32 = 0,
    pAttachmentImageInfos: [*]const FramebufferAttachmentImageInfo = undefined,
};
pub const PhysicalDeviceSeparateDepthStencilLayoutsFeatures = extern struct {
    sType: StructureType = .physical_device_separate_depth_stencil_layouts_features,
    pNext: ?*anyopaque = null,
    separateDepthStencilLayouts: Bool = .False,
};
pub const AttachmentReferenceStencilLayout = extern struct {
    sType: StructureType = .attachment_reference_stencil_layout,
    pNext: ?*anyopaque = null,
    stencilLayout: ImageLayout = .undefined,
};
pub const AttachmentDescriptionStencilLayout = extern struct {
    sType: StructureType = .attachment_description_stencil_layout,
    pNext: ?*anyopaque = null,
    stencilInitialLayout: ImageLayout = .undefined,
    stencilFinalLayout: ImageLayout = .undefined,
};
pub const PhysicalDeviceVulkan13Features = extern struct {
    sType: StructureType = .physical_device_vulkan_1_3_features,
    pNext: ?*anyopaque = null,
    robustImageAccess: Bool = .False,
    inlineUniformBlock: Bool = .False,
    descriptorBindingInlineUniformBlockUpdateAfterBind: Bool = .False,
    pipelineCreationCacheControl: Bool = .False,
    privateData: Bool = .False,
    shaderDemoteToHelperInvocation: Bool = .False,
    shaderTerminateInvocation: Bool = .False,
    subgroupSizeControl: Bool = .False,
    computeFullSubgroups: Bool = .False,
    synchronization2: Bool = .False,
    textureCompressionASTC_HDR: Bool = .False,
    shaderZeroInitializeWorkgroupMemory: Bool = .False,
    dynamicRendering: Bool = .False,
    shaderIntegerDotProduct: Bool = .False,
    maintenance4: Bool = .False,
};
pub const PhysicalDeviceVulkan13Properties = extern struct {
    sType: StructureType = .physical_device_vulkan_1_3_properties,
    pNext: ?*anyopaque = null,
    minSubgroupSize: u32 = 0,
    maxSubgroupSize: u32 = 0,
    maxComputeWorkgroupSubgroups: u32 = 0,
    requiredSubgroupSizeStages: ShaderStageFlags = .{},
    maxInlineUniformBlockSize: u32 = 0,
    maxPerStageDescriptorInlineUniformBlocks: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindInlineUniformBlocks: u32 = 0,
    maxDescriptorSetInlineUniformBlocks: u32 = 0,
    maxDescriptorSetUpdateAfterBindInlineUniformBlocks: u32 = 0,
    maxInlineUniformTotalSize: u32 = 0,
    integerDotProduct8BitUnsignedAccelerated: Bool = .False,
    integerDotProduct8BitSignedAccelerated: Bool = .False,
    integerDotProduct8BitMixedSignednessAccelerated: Bool = .False,
    integerDotProduct4x8BitPackedUnsignedAccelerated: Bool = .False,
    integerDotProduct4x8BitPackedSignedAccelerated: Bool = .False,
    integerDotProduct4x8BitPackedMixedSignednessAccelerated: Bool = .False,
    integerDotProduct16BitUnsignedAccelerated: Bool = .False,
    integerDotProduct16BitSignedAccelerated: Bool = .False,
    integerDotProduct16BitMixedSignednessAccelerated: Bool = .False,
    integerDotProduct32BitUnsignedAccelerated: Bool = .False,
    integerDotProduct32BitSignedAccelerated: Bool = .False,
    integerDotProduct32BitMixedSignednessAccelerated: Bool = .False,
    integerDotProduct64BitUnsignedAccelerated: Bool = .False,
    integerDotProduct64BitSignedAccelerated: Bool = .False,
    integerDotProduct64BitMixedSignednessAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating8BitUnsignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating8BitSignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating8BitMixedSignednessAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating4x8BitPackedUnsignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating4x8BitPackedSignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating4x8BitPackedMixedSignednessAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating16BitUnsignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating16BitSignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating16BitMixedSignednessAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating32BitUnsignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating32BitSignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating32BitMixedSignednessAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating64BitUnsignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating64BitSignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating64BitMixedSignednessAccelerated: Bool = .False,
    storageTexelBufferOffsetAlignmentBytes: DeviceSize = std.mem.zeroes(DeviceSize),
    storageTexelBufferOffsetSingleTexelAlignment: Bool = .False,
    uniformTexelBufferOffsetAlignmentBytes: DeviceSize = std.mem.zeroes(DeviceSize),
    uniformTexelBufferOffsetSingleTexelAlignment: Bool = .False,
    maxBufferSize: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const PhysicalDeviceToolProperties = extern struct {
    sType: StructureType = .physical_device_tool_properties,
    pNext: ?*anyopaque = null,
    name: [MaxExtensionNameSize]u8 = @splat(0),
    version: [MaxExtensionNameSize]u8 = @splat(0),
    purposes: ToolPurposeFlags = .{},
    description: [MaxDescriptionSize]u8 = @splat(0),
    layer: [MaxExtensionNameSize]u8 = @splat(0),
};
pub const PhysicalDevicePrivateDataFeatures = extern struct {
    sType: StructureType = .physical_device_private_data_features,
    pNext: ?*anyopaque = null,
    privateData: Bool = .False,
};
pub const DevicePrivateDataCreateInfo = extern struct {
    sType: StructureType = .device_private_data_create_info,
    pNext: ?*const anyopaque = null,
    privateDataSlotRequestCount: u32 = 0,
};
pub const PrivateDataSlotCreateInfo = extern struct {
    sType: StructureType = .private_data_slot_create_info,
    pNext: ?*const anyopaque = null,
    flags: PrivateDataSlotCreateFlags = std.mem.zeroes(PrivateDataSlotCreateFlags),
};
pub const MemoryBarrier2 = extern struct {
    sType: StructureType = .memory_barrier_2,
    pNext: ?*const anyopaque = null,
    srcStageMask: PipelineStageFlags2 = .{},
    srcAccessMask: AccessFlags2 = .{},
    dstStageMask: PipelineStageFlags2 = .{},
    dstAccessMask: AccessFlags2 = .{},
};
pub const BufferMemoryBarrier2 = extern struct {
    sType: StructureType = .buffer_memory_barrier_2,
    pNext: ?*const anyopaque = null,
    srcStageMask: PipelineStageFlags2 = .{},
    srcAccessMask: AccessFlags2 = .{},
    dstStageMask: PipelineStageFlags2 = .{},
    dstAccessMask: AccessFlags2 = .{},
    srcQueueFamilyIndex: u32 = 0,
    dstQueueFamilyIndex: u32 = 0,
    buffer: Buffer = undefined,
    offset: DeviceSize = std.mem.zeroes(DeviceSize),
    size: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const ImageMemoryBarrier2 = extern struct {
    sType: StructureType = .image_memory_barrier_2,
    pNext: ?*const anyopaque = null,
    srcStageMask: PipelineStageFlags2 = .{},
    srcAccessMask: AccessFlags2 = .{},
    dstStageMask: PipelineStageFlags2 = .{},
    dstAccessMask: AccessFlags2 = .{},
    oldLayout: ImageLayout = .undefined,
    newLayout: ImageLayout = .undefined,
    srcQueueFamilyIndex: u32 = 0,
    dstQueueFamilyIndex: u32 = 0,
    image: Image = undefined,
    subresourceRange: ImageSubresourceRange = .{},
};
pub const DependencyInfo = extern struct {
    sType: StructureType = .dependency_info,
    pNext: ?*const anyopaque = null,
    dependencyFlags: DependencyFlags = .{},
    memoryBarrierCount: u32 = 0,
    pMemoryBarriers: [*]const MemoryBarrier2 = undefined,
    bufferMemoryBarrierCount: u32 = 0,
    pBufferMemoryBarriers: [*]const BufferMemoryBarrier2 = undefined,
    imageMemoryBarrierCount: u32 = 0,
    pImageMemoryBarriers: [*]const ImageMemoryBarrier2 = undefined,
};
pub const SemaphoreSubmitInfo = extern struct {
    sType: StructureType = .semaphore_submit_info,
    pNext: ?*const anyopaque = null,
    semaphore: Semaphore = undefined,
    value: u64 = 0,
    stageMask: PipelineStageFlags2 = .{},
    deviceIndex: u32 = 0,
};
pub const CommandBufferSubmitInfo = extern struct {
    sType: StructureType = .command_buffer_submit_info,
    pNext: ?*const anyopaque = null,
    commandBuffer: CommandBuffer = undefined,
    deviceMask: u32 = 0,
};
pub const SubmitInfo2 = extern struct {
    sType: StructureType = .submit_info_2,
    pNext: ?*const anyopaque = null,
    flags: SubmitFlags = .{},
    waitSemaphoreInfoCount: u32 = 0,
    pWaitSemaphoreInfos: [*]const SemaphoreSubmitInfo = undefined,
    commandBufferInfoCount: u32 = 0,
    pCommandBufferInfos: [*]const CommandBufferSubmitInfo = undefined,
    signalSemaphoreInfoCount: u32 = 0,
    pSignalSemaphoreInfos: [*]const SemaphoreSubmitInfo = undefined,
};
pub const PhysicalDeviceSynchronization2Features = extern struct {
    sType: StructureType = .physical_device_synchronization_2_features,
    pNext: ?*anyopaque = null,
    synchronization2: Bool = .False,
};
pub const BufferCopy2 = extern struct {
    sType: StructureType = .buffer_copy_2,
    pNext: ?*const anyopaque = null,
    srcOffset: DeviceSize = std.mem.zeroes(DeviceSize),
    dstOffset: DeviceSize = std.mem.zeroes(DeviceSize),
    size: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const CopyBufferInfo2 = extern struct {
    sType: StructureType = .copy_buffer_info_2,
    pNext: ?*const anyopaque = null,
    srcBuffer: Buffer = undefined,
    dstBuffer: Buffer = undefined,
    regionCount: u32 = 0,
    pRegions: [*]const BufferCopy2 = undefined,
};
pub const ImageCopy2 = extern struct {
    sType: StructureType = .image_copy_2,
    pNext: ?*const anyopaque = null,
    srcSubresource: ImageSubresourceLayers = .{},
    srcOffset: Offset3D = .{},
    dstSubresource: ImageSubresourceLayers = .{},
    dstOffset: Offset3D = .{},
    extent: Extent3D = .{},
};
pub const CopyImageInfo2 = extern struct {
    sType: StructureType = .copy_image_info_2,
    pNext: ?*const anyopaque = null,
    srcImage: Image = undefined,
    srcImageLayout: ImageLayout = .undefined,
    dstImage: Image = undefined,
    dstImageLayout: ImageLayout = .undefined,
    regionCount: u32 = 0,
    pRegions: [*]const ImageCopy2 = undefined,
};
pub const BufferImageCopy2 = extern struct {
    sType: StructureType = .buffer_image_copy_2,
    pNext: ?*const anyopaque = null,
    bufferOffset: DeviceSize = std.mem.zeroes(DeviceSize),
    bufferRowLength: u32 = 0,
    bufferImageHeight: u32 = 0,
    imageSubresource: ImageSubresourceLayers = .{},
    imageOffset: Offset3D = .{},
    imageExtent: Extent3D = .{},
};
pub const CopyBufferToImageInfo2 = extern struct {
    sType: StructureType = .copy_buffer_to_image_info_2,
    pNext: ?*const anyopaque = null,
    srcBuffer: Buffer = undefined,
    dstImage: Image = undefined,
    dstImageLayout: ImageLayout = .undefined,
    regionCount: u32 = 0,
    pRegions: [*]const BufferImageCopy2 = undefined,
};
pub const CopyImageToBufferInfo2 = extern struct {
    sType: StructureType = .copy_image_to_buffer_info_2,
    pNext: ?*const anyopaque = null,
    srcImage: Image = undefined,
    srcImageLayout: ImageLayout = .undefined,
    dstBuffer: Buffer = undefined,
    regionCount: u32 = 0,
    pRegions: [*]const BufferImageCopy2 = undefined,
};
pub const PhysicalDeviceTextureCompressionASTCHDRFeatures = extern struct {
    sType: StructureType = .physical_device_texture_compression_astc_hdr_features,
    pNext: ?*anyopaque = null,
    textureCompressionASTC_HDR: Bool = .False,
};
pub const FormatProperties3 = extern struct {
    sType: StructureType = .format_properties_3,
    pNext: ?*anyopaque = null,
    linearTilingFeatures: FormatFeatureFlags2 = .{},
    optimalTilingFeatures: FormatFeatureFlags2 = .{},
    bufferFeatures: FormatFeatureFlags2 = .{},
};
pub const PhysicalDeviceMaintenance4Features = extern struct {
    sType: StructureType = .physical_device_maintenance_4_features,
    pNext: ?*anyopaque = null,
    maintenance4: Bool = .False,
};
pub const PhysicalDeviceMaintenance4Properties = extern struct {
    sType: StructureType = .physical_device_maintenance_4_properties,
    pNext: ?*anyopaque = null,
    maxBufferSize: DeviceSize = std.mem.zeroes(DeviceSize),
};
pub const DeviceBufferMemoryRequirements = extern struct {
    sType: StructureType = .device_buffer_memory_requirements,
    pNext: ?*const anyopaque = null,
    pCreateInfo: *const BufferCreateInfo = undefined,
};
pub const DeviceImageMemoryRequirements = extern struct {
    sType: StructureType = .device_image_memory_requirements,
    pNext: ?*const anyopaque = null,
    pCreateInfo: *const ImageCreateInfo = undefined,
    planeAspect: ImageAspectFlags = std.mem.zeroes(ImageAspectFlags),
};
pub const PipelineCreationFeedback = extern struct {
    flags: PipelineCreationFeedbackFlags = .{},
    duration: u64 = 0,
};
pub const PipelineCreationFeedbackCreateInfo = extern struct {
    sType: StructureType = .pipeline_creation_feedback_create_info,
    pNext: ?*const anyopaque = null,
    pPipelineCreationFeedback: *PipelineCreationFeedback = undefined,
    pipelineStageCreationFeedbackCount: u32 = 0,
    pPipelineStageCreationFeedbacks: [*]PipelineCreationFeedback = undefined,
};
pub const PhysicalDeviceShaderTerminateInvocationFeatures = extern struct {
    sType: StructureType = .physical_device_shader_terminate_invocation_features,
    pNext: ?*anyopaque = null,
    shaderTerminateInvocation: Bool = .False,
};
pub const PhysicalDeviceShaderDemoteToHelperInvocationFeatures = extern struct {
    sType: StructureType = .physical_device_shader_demote_to_helper_invocation_features,
    pNext: ?*anyopaque = null,
    shaderDemoteToHelperInvocation: Bool = .False,
};
pub const PhysicalDevicePipelineCreationCacheControlFeatures = extern struct {
    sType: StructureType = .physical_device_pipeline_creation_cache_control_features,
    pNext: ?*anyopaque = null,
    pipelineCreationCacheControl: Bool = .False,
};
pub const PhysicalDeviceZeroInitializeWorkgroupMemoryFeatures = extern struct {
    sType: StructureType = .physical_device_zero_initialize_workgroup_memory_features,
    pNext: ?*anyopaque = null,
    shaderZeroInitializeWorkgroupMemory: Bool = .False,
};
pub const PhysicalDeviceImageRobustnessFeatures = extern struct {
    sType: StructureType = .physical_device_image_robustness_features,
    pNext: ?*anyopaque = null,
    robustImageAccess: Bool = .False,
};
pub const PhysicalDeviceSubgroupSizeControlFeatures = extern struct {
    sType: StructureType = .physical_device_subgroup_size_control_features,
    pNext: ?*anyopaque = null,
    subgroupSizeControl: Bool = .False,
    computeFullSubgroups: Bool = .False,
};
pub const PhysicalDeviceSubgroupSizeControlProperties = extern struct {
    sType: StructureType = .physical_device_subgroup_size_control_properties,
    pNext: ?*anyopaque = null,
    minSubgroupSize: u32 = 0,
    maxSubgroupSize: u32 = 0,
    maxComputeWorkgroupSubgroups: u32 = 0,
    requiredSubgroupSizeStages: ShaderStageFlags = .{},
};
pub const PipelineShaderStageRequiredSubgroupSizeCreateInfo = extern struct {
    sType: StructureType = .pipeline_shader_stage_required_subgroup_size_create_info,
    pNext: ?*const anyopaque = null,
    requiredSubgroupSize: u32 = 0,
};
pub const PhysicalDeviceInlineUniformBlockFeatures = extern struct {
    sType: StructureType = .physical_device_inline_uniform_block_features,
    pNext: ?*anyopaque = null,
    inlineUniformBlock: Bool = .False,
    descriptorBindingInlineUniformBlockUpdateAfterBind: Bool = .False,
};
pub const PhysicalDeviceInlineUniformBlockProperties = extern struct {
    sType: StructureType = .physical_device_inline_uniform_block_properties,
    pNext: ?*anyopaque = null,
    maxInlineUniformBlockSize: u32 = 0,
    maxPerStageDescriptorInlineUniformBlocks: u32 = 0,
    maxPerStageDescriptorUpdateAfterBindInlineUniformBlocks: u32 = 0,
    maxDescriptorSetInlineUniformBlocks: u32 = 0,
    maxDescriptorSetUpdateAfterBindInlineUniformBlocks: u32 = 0,
};
pub const WriteDescriptorSetInlineUniformBlock = extern struct {
    sType: StructureType = .write_descriptor_set_inline_uniform_block,
    pNext: ?*const anyopaque = null,
    dataSize: u32 = 0,
    pData: [*]const u8 = undefined,
};
pub const DescriptorPoolInlineUniformBlockCreateInfo = extern struct {
    sType: StructureType = .descriptor_pool_inline_uniform_block_create_info,
    pNext: ?*const anyopaque = null,
    maxInlineUniformBlockBindings: u32 = 0,
};
pub const PhysicalDeviceShaderIntegerDotProductFeatures = extern struct {
    sType: StructureType = .physical_device_shader_integer_dot_product_features,
    pNext: ?*anyopaque = null,
    shaderIntegerDotProduct: Bool = .False,
};
pub const PhysicalDeviceShaderIntegerDotProductProperties = extern struct {
    sType: StructureType = .physical_device_shader_integer_dot_product_properties,
    pNext: ?*anyopaque = null,
    integerDotProduct8BitUnsignedAccelerated: Bool = .False,
    integerDotProduct8BitSignedAccelerated: Bool = .False,
    integerDotProduct8BitMixedSignednessAccelerated: Bool = .False,
    integerDotProduct4x8BitPackedUnsignedAccelerated: Bool = .False,
    integerDotProduct4x8BitPackedSignedAccelerated: Bool = .False,
    integerDotProduct4x8BitPackedMixedSignednessAccelerated: Bool = .False,
    integerDotProduct16BitUnsignedAccelerated: Bool = .False,
    integerDotProduct16BitSignedAccelerated: Bool = .False,
    integerDotProduct16BitMixedSignednessAccelerated: Bool = .False,
    integerDotProduct32BitUnsignedAccelerated: Bool = .False,
    integerDotProduct32BitSignedAccelerated: Bool = .False,
    integerDotProduct32BitMixedSignednessAccelerated: Bool = .False,
    integerDotProduct64BitUnsignedAccelerated: Bool = .False,
    integerDotProduct64BitSignedAccelerated: Bool = .False,
    integerDotProduct64BitMixedSignednessAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating8BitUnsignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating8BitSignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating8BitMixedSignednessAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating4x8BitPackedUnsignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating4x8BitPackedSignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating4x8BitPackedMixedSignednessAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating16BitUnsignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating16BitSignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating16BitMixedSignednessAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating32BitUnsignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating32BitSignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating32BitMixedSignednessAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating64BitUnsignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating64BitSignedAccelerated: Bool = .False,
    integerDotProductAccumulatingSaturating64BitMixedSignednessAccelerated: Bool = .False,
};
pub const PhysicalDeviceTexelBufferAlignmentProperties = extern struct {
    sType: StructureType = .physical_device_texel_buffer_alignment_properties,
    pNext: ?*anyopaque = null,
    storageTexelBufferOffsetAlignmentBytes: DeviceSize = std.mem.zeroes(DeviceSize),
    storageTexelBufferOffsetSingleTexelAlignment: Bool = .False,
    uniformTexelBufferOffsetAlignmentBytes: DeviceSize = std.mem.zeroes(DeviceSize),
    uniformTexelBufferOffsetSingleTexelAlignment: Bool = .False,
};
pub const ImageBlit2 = extern struct {
    sType: StructureType = .image_blit_2,
    pNext: ?*const anyopaque = null,
    srcSubresource: ImageSubresourceLayers = .{},
    srcOffsets: [2]Offset3D = @splat(.{}),
    dstSubresource: ImageSubresourceLayers = .{},
    dstOffsets: [2]Offset3D = @splat(.{}),
};
pub const BlitImageInfo2 = extern struct {
    sType: StructureType = .blit_image_info_2,
    pNext: ?*const anyopaque = null,
    srcImage: Image = undefined,
    srcImageLayout: ImageLayout = .undefined,
    dstImage: Image = undefined,
    dstImageLayout: ImageLayout = .undefined,
    regionCount: u32 = 0,
    pRegions: [*]const ImageBlit2 = undefined,
    filter: Filter = .nearest,
};
pub const ImageResolve2 = extern struct {
    sType: StructureType = .image_resolve_2,
    pNext: ?*const anyopaque = null,
    srcSubresource: ImageSubresourceLayers = .{},
    srcOffset: Offset3D = .{},
    dstSubresource: ImageSubresourceLayers = .{},
    dstOffset: Offset3D = .{},
    extent: Extent3D = .{},
};
pub const ResolveImageInfo2 = extern struct {
    sType: StructureType = .resolve_image_info_2,
    pNext: ?*const anyopaque = null,
    srcImage: Image = undefined,
    srcImageLayout: ImageLayout = .undefined,
    dstImage: Image = undefined,
    dstImageLayout: ImageLayout = .undefined,
    regionCount: u32 = 0,
    pRegions: [*]const ImageResolve2 = undefined,
};
pub const RenderingAttachmentInfo = extern struct {
    sType: StructureType = .rendering_attachment_info,
    pNext: ?*const anyopaque = null,
    imageView: ?ImageView = null,
    imageLayout: ImageLayout = .undefined,
    resolveMode: ResolveModeFlags = std.mem.zeroes(ResolveModeFlags),
    resolveImageView: ?ImageView = null,
    resolveImageLayout: ImageLayout = .undefined,
    loadOp: AttachmentLoadOp = .load,
    storeOp: AttachmentStoreOp = .store,
    clearValue: ClearValue,
};
pub const RenderingInfo = extern struct {
    sType: StructureType = .rendering_info,
    pNext: ?*const anyopaque = null,
    flags: RenderingFlags = .{},
    renderArea: Rect2D = .{},
    layerCount: u32 = 0,
    viewMask: u32 = 0,
    colorAttachmentCount: u32 = 0,
    pColorAttachments: [*]const RenderingAttachmentInfo = undefined,
    pDepthAttachment: ?*const RenderingAttachmentInfo = null,
    pStencilAttachment: ?*const RenderingAttachmentInfo = null,
};
pub const PipelineRenderingCreateInfo = extern struct {
    sType: StructureType = .pipeline_rendering_create_info,
    pNext: ?*const anyopaque = null,
    viewMask: u32 = 0,
    colorAttachmentCount: u32 = 0,
    pColorAttachmentFormats: [*]const Format = undefined,
    depthAttachmentFormat: Format = .undefined,
    stencilAttachmentFormat: Format = .undefined,
};
pub const PhysicalDeviceDynamicRenderingFeatures = extern struct {
    sType: StructureType = .physical_device_dynamic_rendering_features,
    pNext: ?*anyopaque = null,
    dynamicRendering: Bool = .False,
};
pub const CommandBufferInheritanceRenderingInfo = extern struct {
    sType: StructureType = .command_buffer_inheritance_rendering_info,
    pNext: ?*const anyopaque = null,
    flags: RenderingFlags = .{},
    viewMask: u32 = 0,
    colorAttachmentCount: u32 = 0,
    pColorAttachmentFormats: [*]const Format = undefined,
    depthAttachmentFormat: Format = .undefined,
    stencilAttachmentFormat: Format = .undefined,
    rasterizationSamples: SampleCountFlags = std.mem.zeroes(SampleCountFlags),
};
pub const SurfaceCapabilitiesKHR = extern struct {
    minImageCount: u32 = 0,
    maxImageCount: u32 = 0,
    currentExtent: Extent2D = .{},
    minImageExtent: Extent2D = .{},
    maxImageExtent: Extent2D = .{},
    maxImageArrayLayers: u32 = 0,
    supportedTransforms: SurfaceTransformFlagsKHR = .{},
    currentTransform: SurfaceTransformFlagsKHR = std.mem.zeroes(SurfaceTransformFlagsKHR),
    supportedCompositeAlpha: CompositeAlphaFlagsKHR = .{},
    supportedUsageFlags: ImageUsageFlags = .{},
};
pub const SurfaceFormatKHR = extern struct {
    format: Format = .undefined,
    colorSpace: ColorSpaceKHR = .srgb_nonlinear,
};
pub const SwapchainCreateInfoKHR = extern struct {
    sType: StructureType = .swapchain_create_infoKHR,
    pNext: ?*const anyopaque = null,
    flags: SwapchainCreateFlagsKHR = .{},
    surface: SurfaceKHR = undefined,
    minImageCount: u32 = 0,
    imageFormat: Format = .undefined,
    imageColorSpace: ColorSpaceKHR = .srgb_nonlinear,
    imageExtent: Extent2D = .{},
    imageArrayLayers: u32 = 0,
    imageUsage: ImageUsageFlags = .{},
    imageSharingMode: SharingMode = .exclusive,
    queueFamilyIndexCount: u32 = 0,
    pQueueFamilyIndices: [*]const u32 = undefined,
    preTransform: SurfaceTransformFlagsKHR = std.mem.zeroes(SurfaceTransformFlagsKHR),
    compositeAlpha: CompositeAlphaFlagsKHR = std.mem.zeroes(CompositeAlphaFlagsKHR),
    presentMode: PresentModeKHR = .immediate,
    clipped: Bool = .False,
    oldSwapchain: ?SwapchainKHR = null,
};
pub const PresentInfoKHR = extern struct {
    sType: StructureType = .present_infoKHR,
    pNext: ?*const anyopaque = null,
    waitSemaphoreCount: u32 = 0,
    pWaitSemaphores: [*]const Semaphore = undefined,
    swapchainCount: u32 = 0,
    pSwapchains: [*]const SwapchainKHR = undefined,
    pImageIndices: [*]const u32 = undefined,
    pResults: ?[*]Result = null,
};
pub const ImageSwapchainCreateInfoKHR = extern struct {
    sType: StructureType = .image_swapchain_create_infoKHR,
    pNext: ?*const anyopaque = null,
    swapchain: ?SwapchainKHR = null,
};
pub const BindImageMemorySwapchainInfoKHR = extern struct {
    sType: StructureType = .bind_image_memory_swapchain_infoKHR,
    pNext: ?*const anyopaque = null,
    swapchain: SwapchainKHR = undefined,
    imageIndex: u32 = 0,
};
pub const AcquireNextImageInfoKHR = extern struct {
    sType: StructureType = .acquire_next_image_infoKHR,
    pNext: ?*const anyopaque = null,
    swapchain: SwapchainKHR = undefined,
    timeout: u64 = 0,
    semaphore: ?Semaphore = null,
    fence: ?Fence = null,
    deviceMask: u32 = 0,
};
pub const DeviceGroupPresentCapabilitiesKHR = extern struct {
    sType: StructureType = .device_group_present_capabilitiesKHR,
    pNext: ?*anyopaque = null,
    presentMask: [MaxDeviceGroupSize]u32 = @splat(0),
    modes: DeviceGroupPresentModeFlagsKHR = .{},
};
pub const DeviceGroupPresentInfoKHR = extern struct {
    sType: StructureType = .device_group_present_infoKHR,
    pNext: ?*const anyopaque = null,
    swapchainCount: u32 = 0,
    pDeviceMasks: [*]const u32 = undefined,
    mode: DeviceGroupPresentModeFlagsKHR = std.mem.zeroes(DeviceGroupPresentModeFlagsKHR),
};
pub const DeviceGroupSwapchainCreateInfoKHR = extern struct {
    sType: StructureType = .device_group_swapchain_create_infoKHR,
    pNext: ?*const anyopaque = null,
    modes: DeviceGroupPresentModeFlagsKHR = .{},
};
pub const DebugUtilsMessengerCreateInfoEXT = extern struct {
    sType: StructureType = .debug_utils_messenger_create_infoEXT,
    pNext: ?*const anyopaque = null,
    flags: DebugUtilsMessengerCreateFlagsEXT = std.mem.zeroes(DebugUtilsMessengerCreateFlagsEXT),
    messageSeverity: DebugUtilsMessageSeverityFlagsEXT = .{},
    messageType: DebugUtilsMessageTypeFlagsEXT = .{},
    pfnUserCallback: *pfn.DebugUtilsMessengerCallbackEXT = undefined,
    pUserData: ?*anyopaque = null,
};
pub const DebugUtilsObjectTagInfoEXT = extern struct {
    sType: StructureType = .debug_utils_object_tag_infoEXT,
    pNext: ?*const anyopaque = null,
    objectType: ObjectType = .unknown,
    objectHandle: u64 = 0,
    tagName: u64 = 0,
    tagSize: u64 = std.mem.zeroes(u64),
    pTag: [*]const u8 = undefined,
};
pub fn createInstance(pCreateInfo: *const InstanceCreateInfo, pAllocator: ?*const AllocationCallbacks, pInstance: *Instance) ResultErr!void {
    return makeError(ResultErr, table.global.vkCreateInstance(pCreateInfo, pAllocator, pInstance));
}
pub fn destroyInstance(instance: ?Instance, pAllocator: ?*const AllocationCallbacks) void {
    return table.instance.vkDestroyInstance(instance, pAllocator);
}
pub fn enumeratePhysicalDevices(instance: Instance, pPhysicalDeviceCount: ?*u32, pPhysicalDevices: ?[*]PhysicalDevice) ResultErr!void {
    return makeError(ResultErr, table.instance.vkEnumeratePhysicalDevices(instance, pPhysicalDeviceCount, pPhysicalDevices));
}
pub fn getPhysicalDeviceFeatures(physicalDevice: PhysicalDevice, pFeatures: *PhysicalDeviceFeatures) void {
    return table.instance.vkGetPhysicalDeviceFeatures(physicalDevice, pFeatures);
}
pub fn getPhysicalDeviceFormatProperties(physicalDevice: PhysicalDevice, format: Format, pFormatProperties: *FormatProperties) void {
    return table.instance.vkGetPhysicalDeviceFormatProperties(physicalDevice, format, pFormatProperties);
}
pub fn getPhysicalDeviceImageFormatProperties(physicalDevice: PhysicalDevice, format: Format, Type: ImageType, tiling: ImageTiling, usage: ImageUsageFlags, flags: ImageCreateFlags, pImageFormatProperties: *ImageFormatProperties) ResultErr!void {
    return makeError(ResultErr, table.instance.vkGetPhysicalDeviceImageFormatProperties(physicalDevice, format, Type, tiling, usage, flags, pImageFormatProperties));
}
pub fn getPhysicalDeviceProperties(physicalDevice: PhysicalDevice, pProperties: *PhysicalDeviceProperties) void {
    return table.instance.vkGetPhysicalDeviceProperties(physicalDevice, pProperties);
}
pub fn getPhysicalDeviceQueueFamilyProperties(physicalDevice: PhysicalDevice, pQueueFamilyPropertyCount: ?*u32, pQueueFamilyProperties: ?[*]QueueFamilyProperties) void {
    return table.instance.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, pQueueFamilyPropertyCount, pQueueFamilyProperties);
}
pub fn getPhysicalDeviceMemoryProperties(physicalDevice: PhysicalDevice, pMemoryProperties: *PhysicalDeviceMemoryProperties) void {
    return table.instance.vkGetPhysicalDeviceMemoryProperties(physicalDevice, pMemoryProperties);
}
pub fn getInstanceProcAddr(instance: ?Instance, pName: [*:0]const u8) pfn.VoidFunction {
    return table.instance.vkGetInstanceProcAddr(instance, pName);
}
pub fn getDeviceProcAddr(device: Device, pName: [*:0]const u8) pfn.VoidFunction {
    return table.device.vkGetDeviceProcAddr(device, pName);
}
pub fn createDevice(physicalDevice: PhysicalDevice, pCreateInfo: *const DeviceCreateInfo, pAllocator: ?*const AllocationCallbacks, pDevice: *Device) ResultErr!void {
    return makeError(ResultErr, table.instance.vkCreateDevice(physicalDevice, pCreateInfo, pAllocator, pDevice));
}
pub fn destroyDevice(device: ?Device, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyDevice(device, pAllocator);
}
pub fn enumerateInstanceExtensionProperties(pLayerName: ?[*:0]const u8, pPropertyCount: ?*u32, pProperties: ?[*]ExtensionProperties) ResultErr!void {
    return makeError(ResultErr, table.global.vkEnumerateInstanceExtensionProperties(pLayerName, pPropertyCount, pProperties));
}
pub fn enumerateDeviceExtensionProperties(physicalDevice: PhysicalDevice, pLayerName: ?[*:0]const u8, pPropertyCount: ?*u32, pProperties: ?[*]ExtensionProperties) ResultErr!void {
    return makeError(ResultErr, table.instance.vkEnumerateDeviceExtensionProperties(physicalDevice, pLayerName, pPropertyCount, pProperties));
}
pub fn enumerateInstanceLayerProperties(pPropertyCount: ?*u32, pProperties: ?[*]LayerProperties) ResultErr!void {
    return makeError(ResultErr, table.global.vkEnumerateInstanceLayerProperties(pPropertyCount, pProperties));
}
pub fn enumerateDeviceLayerProperties(physicalDevice: PhysicalDevice, pPropertyCount: ?*u32, pProperties: ?[*]LayerProperties) ResultErr!void {
    return makeError(ResultErr, table.instance.vkEnumerateDeviceLayerProperties(physicalDevice, pPropertyCount, pProperties));
}
pub fn getDeviceQueue(device: Device, queueFamilyIndex: u32, queueIndex: u32, pQueue: *Queue) void {
    return table.device.vkGetDeviceQueue(device, queueFamilyIndex, queueIndex, pQueue);
}
pub fn queueSubmit(queue: Queue, submitCount: u32, pSubmits: [*]const SubmitInfo, fence: ?Fence) ResultErr!void {
    return makeError(ResultErr, table.device.vkQueueSubmit(queue, submitCount, pSubmits, fence));
}
pub fn queueWaitIdle(queue: Queue) ResultErr!void {
    return makeError(ResultErr, table.device.vkQueueWaitIdle(queue));
}
pub fn deviceWaitIdle(device: Device) ResultErr!void {
    return makeError(ResultErr, table.device.vkDeviceWaitIdle(device));
}
pub fn allocateMemory(device: Device, pAllocateInfo: *const MemoryAllocateInfo, pAllocator: ?*const AllocationCallbacks, pMemory: *DeviceMemory) ResultErr!void {
    return makeError(ResultErr, table.device.vkAllocateMemory(device, pAllocateInfo, pAllocator, pMemory));
}
pub fn freeMemory(device: Device, memory: ?DeviceMemory, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkFreeMemory(device, memory, pAllocator);
}
pub fn mapMemory(device: Device, memory: DeviceMemory, offset: DeviceSize, size: DeviceSize, flags: MemoryMapFlags, ppData: [*]const ?*anyopaque) ResultErr!void {
    return makeError(ResultErr, table.device.vkMapMemory(device, memory, offset, size, flags, ppData));
}
pub fn unmapMemory(device: Device, memory: DeviceMemory) void {
    return table.device.vkUnmapMemory(device, memory);
}
pub fn flushMappedMemoryRanges(device: Device, memoryRangeCount: u32, pMemoryRanges: [*]const MappedMemoryRange) ResultErr!void {
    return makeError(ResultErr, table.device.vkFlushMappedMemoryRanges(device, memoryRangeCount, pMemoryRanges));
}
pub fn invalidateMappedMemoryRanges(device: Device, memoryRangeCount: u32, pMemoryRanges: [*]const MappedMemoryRange) ResultErr!void {
    return makeError(ResultErr, table.device.vkInvalidateMappedMemoryRanges(device, memoryRangeCount, pMemoryRanges));
}
pub fn getDeviceMemoryCommitment(device: Device, memory: DeviceMemory, pCommittedMemoryInBytes: *DeviceSize) void {
    return table.device.vkGetDeviceMemoryCommitment(device, memory, pCommittedMemoryInBytes);
}
pub fn bindBufferMemory(device: Device, buffer: Buffer, memory: DeviceMemory, memoryOffset: DeviceSize) ResultErr!void {
    return makeError(ResultErr, table.device.vkBindBufferMemory(device, buffer, memory, memoryOffset));
}
pub fn bindImageMemory(device: Device, image: Image, memory: DeviceMemory, memoryOffset: DeviceSize) ResultErr!void {
    return makeError(ResultErr, table.device.vkBindImageMemory(device, image, memory, memoryOffset));
}
pub fn getBufferMemoryRequirements(device: Device, buffer: Buffer, pMemoryRequirements: *MemoryRequirements) void {
    return table.device.vkGetBufferMemoryRequirements(device, buffer, pMemoryRequirements);
}
pub fn getImageMemoryRequirements(device: Device, image: Image, pMemoryRequirements: *MemoryRequirements) void {
    return table.device.vkGetImageMemoryRequirements(device, image, pMemoryRequirements);
}
pub fn getImageSparseMemoryRequirements(device: Device, image: Image, pSparseMemoryRequirementCount: ?*u32, pSparseMemoryRequirements: ?[*]SparseImageMemoryRequirements) void {
    return table.device.vkGetImageSparseMemoryRequirements(device, image, pSparseMemoryRequirementCount, pSparseMemoryRequirements);
}
pub fn getPhysicalDeviceSparseImageFormatProperties(physicalDevice: PhysicalDevice, format: Format, Type: ImageType, samples: SampleCountFlags, usage: ImageUsageFlags, tiling: ImageTiling, pPropertyCount: ?*u32, pProperties: ?[*]SparseImageFormatProperties) void {
    return table.instance.vkGetPhysicalDeviceSparseImageFormatProperties(physicalDevice, format, Type, samples, usage, tiling, pPropertyCount, pProperties);
}
pub fn queueBindSparse(queue: Queue, bindInfoCount: u32, pBindInfo: [*]const BindSparseInfo, fence: ?Fence) ResultErr!void {
    return makeError(ResultErr, table.device.vkQueueBindSparse(queue, bindInfoCount, pBindInfo, fence));
}
pub fn createFence(device: Device, pCreateInfo: *const FenceCreateInfo, pAllocator: ?*const AllocationCallbacks, pFence: *Fence) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateFence(device, pCreateInfo, pAllocator, pFence));
}
pub fn destroyFence(device: Device, fence: ?Fence, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyFence(device, fence, pAllocator);
}
pub fn resetFences(device: Device, fenceCount: u32, pFences: [*]const Fence) ResultErr!void {
    return makeError(ResultErr, table.device.vkResetFences(device, fenceCount, pFences));
}
pub fn getFenceStatus(device: Device, fence: Fence) ResultErr!void {
    return makeError(ResultErr, table.device.vkGetFenceStatus(device, fence));
}
pub fn waitForFences(device: Device, fenceCount: u32, pFences: [*]const Fence, waitAll: Bool, timeout: u64) ResultErr!void {
    return makeError(ResultErr, table.device.vkWaitForFences(device, fenceCount, pFences, waitAll, timeout));
}
pub fn createSemaphore(device: Device, pCreateInfo: *const SemaphoreCreateInfo, pAllocator: ?*const AllocationCallbacks, pSemaphore: *Semaphore) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateSemaphore(device, pCreateInfo, pAllocator, pSemaphore));
}
pub fn destroySemaphore(device: Device, semaphore: ?Semaphore, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroySemaphore(device, semaphore, pAllocator);
}
pub fn createQueryPool(device: Device, pCreateInfo: *const QueryPoolCreateInfo, pAllocator: ?*const AllocationCallbacks, pQueryPool: *QueryPool) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateQueryPool(device, pCreateInfo, pAllocator, pQueryPool));
}
pub fn destroyQueryPool(device: Device, queryPool: ?QueryPool, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyQueryPool(device, queryPool, pAllocator);
}
pub fn getQueryPoolResults(device: Device, queryPool: QueryPool, firstQuery: u32, queryCount: u32, dataSize: u64, pData: [*]u8, stride: DeviceSize, flags: QueryResultFlags) ResultErr!void {
    return makeError(ResultErr, table.device.vkGetQueryPoolResults(device, queryPool, firstQuery, queryCount, dataSize, pData, stride, flags));
}
pub fn createBuffer(device: Device, pCreateInfo: *const BufferCreateInfo, pAllocator: ?*const AllocationCallbacks, pBuffer: *Buffer) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateBuffer(device, pCreateInfo, pAllocator, pBuffer));
}
pub fn destroyBuffer(device: Device, buffer: ?Buffer, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyBuffer(device, buffer, pAllocator);
}
pub fn createImage(device: Device, pCreateInfo: *const ImageCreateInfo, pAllocator: ?*const AllocationCallbacks, pImage: *Image) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateImage(device, pCreateInfo, pAllocator, pImage));
}
pub fn destroyImage(device: Device, image: ?Image, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyImage(device, image, pAllocator);
}
pub fn getImageSubresourceLayout(device: Device, image: Image, pSubresource: *const ImageSubresource, pLayout: *SubresourceLayout) void {
    return table.device.vkGetImageSubresourceLayout(device, image, pSubresource, pLayout);
}
pub fn createImageView(device: Device, pCreateInfo: *const ImageViewCreateInfo, pAllocator: ?*const AllocationCallbacks, pView: *ImageView) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateImageView(device, pCreateInfo, pAllocator, pView));
}
pub fn destroyImageView(device: Device, imageView: ?ImageView, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyImageView(device, imageView, pAllocator);
}
pub fn createCommandPool(device: Device, pCreateInfo: *const CommandPoolCreateInfo, pAllocator: ?*const AllocationCallbacks, pCommandPool: *CommandPool) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateCommandPool(device, pCreateInfo, pAllocator, pCommandPool));
}
pub fn destroyCommandPool(device: Device, commandPool: ?CommandPool, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyCommandPool(device, commandPool, pAllocator);
}
pub fn resetCommandPool(device: Device, commandPool: CommandPool, flags: CommandPoolResetFlags) ResultErr!void {
    return makeError(ResultErr, table.device.vkResetCommandPool(device, commandPool, flags));
}
pub fn allocateCommandBuffers(device: Device, pAllocateInfo: *const CommandBufferAllocateInfo, pCommandBuffers: [*]CommandBuffer) ResultErr!void {
    return makeError(ResultErr, table.device.vkAllocateCommandBuffers(device, pAllocateInfo, pCommandBuffers));
}
pub fn freeCommandBuffers(device: Device, commandPool: CommandPool, commandBufferCount: u32, pCommandBuffers: [*]const CommandBuffer) void {
    return table.device.vkFreeCommandBuffers(device, commandPool, commandBufferCount, pCommandBuffers);
}
pub fn beginCommandBuffer(commandBuffer: CommandBuffer, pBeginInfo: *const CommandBufferBeginInfo) ResultErr!void {
    return makeError(ResultErr, table.device.vkBeginCommandBuffer(commandBuffer, pBeginInfo));
}
pub fn endCommandBuffer(commandBuffer: CommandBuffer) ResultErr!void {
    return makeError(ResultErr, table.device.vkEndCommandBuffer(commandBuffer));
}
pub fn resetCommandBuffer(commandBuffer: CommandBuffer, flags: CommandBufferResetFlags) ResultErr!void {
    return makeError(ResultErr, table.device.vkResetCommandBuffer(commandBuffer, flags));
}
pub fn cmdCopyBuffer(commandBuffer: CommandBuffer, srcBuffer: Buffer, dstBuffer: Buffer, regionCount: u32, pRegions: [*]const BufferCopy) void {
    return table.device.vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, regionCount, pRegions);
}
pub fn cmdCopyImage(commandBuffer: CommandBuffer, srcImage: Image, srcImageLayout: ImageLayout, dstImage: Image, dstImageLayout: ImageLayout, regionCount: u32, pRegions: [*]const ImageCopy) void {
    return table.device.vkCmdCopyImage(commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions);
}
pub fn cmdCopyBufferToImage(commandBuffer: CommandBuffer, srcBuffer: Buffer, dstImage: Image, dstImageLayout: ImageLayout, regionCount: u32, pRegions: [*]const BufferImageCopy) void {
    return table.device.vkCmdCopyBufferToImage(commandBuffer, srcBuffer, dstImage, dstImageLayout, regionCount, pRegions);
}
pub fn cmdCopyImageToBuffer(commandBuffer: CommandBuffer, srcImage: Image, srcImageLayout: ImageLayout, dstBuffer: Buffer, regionCount: u32, pRegions: [*]const BufferImageCopy) void {
    return table.device.vkCmdCopyImageToBuffer(commandBuffer, srcImage, srcImageLayout, dstBuffer, regionCount, pRegions);
}
pub fn cmdUpdateBuffer(commandBuffer: CommandBuffer, dstBuffer: Buffer, dstOffset: DeviceSize, dataSize: DeviceSize, pData: [*]const u8) void {
    return table.device.vkCmdUpdateBuffer(commandBuffer, dstBuffer, dstOffset, dataSize, pData);
}
pub fn cmdFillBuffer(commandBuffer: CommandBuffer, dstBuffer: Buffer, dstOffset: DeviceSize, size: DeviceSize, data: u32) void {
    return table.device.vkCmdFillBuffer(commandBuffer, dstBuffer, dstOffset, size, data);
}
pub fn cmdPipelineBarrier(commandBuffer: CommandBuffer, srcStageMask: PipelineStageFlags, dstStageMask: PipelineStageFlags, dependencyFlags: DependencyFlags, memoryBarrierCount: u32, pMemoryBarriers: [*]const MemoryBarrier, bufferMemoryBarrierCount: u32, pBufferMemoryBarriers: [*]const BufferMemoryBarrier, imageMemoryBarrierCount: u32, pImageMemoryBarriers: [*]const ImageMemoryBarrier) void {
    return table.device.vkCmdPipelineBarrier(commandBuffer, srcStageMask, dstStageMask, dependencyFlags, memoryBarrierCount, pMemoryBarriers, bufferMemoryBarrierCount, pBufferMemoryBarriers, imageMemoryBarrierCount, pImageMemoryBarriers);
}
pub fn cmdBeginQuery(commandBuffer: CommandBuffer, queryPool: QueryPool, query: u32, flags: QueryControlFlags) void {
    return table.device.vkCmdBeginQuery(commandBuffer, queryPool, query, flags);
}
pub fn cmdEndQuery(commandBuffer: CommandBuffer, queryPool: QueryPool, query: u32) void {
    return table.device.vkCmdEndQuery(commandBuffer, queryPool, query);
}
pub fn cmdResetQueryPool(commandBuffer: CommandBuffer, queryPool: QueryPool, firstQuery: u32, queryCount: u32) void {
    return table.device.vkCmdResetQueryPool(commandBuffer, queryPool, firstQuery, queryCount);
}
pub fn cmdWriteTimestamp(commandBuffer: CommandBuffer, pipelineStage: PipelineStageFlags, queryPool: QueryPool, query: u32) void {
    return table.device.vkCmdWriteTimestamp(commandBuffer, pipelineStage, queryPool, query);
}
pub fn cmdCopyQueryPoolResults(commandBuffer: CommandBuffer, queryPool: QueryPool, firstQuery: u32, queryCount: u32, dstBuffer: Buffer, dstOffset: DeviceSize, stride: DeviceSize, flags: QueryResultFlags) void {
    return table.device.vkCmdCopyQueryPoolResults(commandBuffer, queryPool, firstQuery, queryCount, dstBuffer, dstOffset, stride, flags);
}
pub fn cmdExecuteCommands(commandBuffer: CommandBuffer, commandBufferCount: u32, pCommandBuffers: [*]const CommandBuffer) void {
    return table.device.vkCmdExecuteCommands(commandBuffer, commandBufferCount, pCommandBuffers);
}
pub fn createEvent(device: Device, pCreateInfo: *const EventCreateInfo, pAllocator: ?*const AllocationCallbacks, pEvent: *Event) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateEvent(device, pCreateInfo, pAllocator, pEvent));
}
pub fn destroyEvent(device: Device, event: ?Event, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyEvent(device, event, pAllocator);
}
pub fn getEventStatus(device: Device, event: Event) ResultErr!void {
    return makeError(ResultErr, table.device.vkGetEventStatus(device, event));
}
pub fn setEvent(device: Device, event: Event) ResultErr!void {
    return makeError(ResultErr, table.device.vkSetEvent(device, event));
}
pub fn resetEvent(device: Device, event: Event) ResultErr!void {
    return makeError(ResultErr, table.device.vkResetEvent(device, event));
}
pub fn createBufferView(device: Device, pCreateInfo: *const BufferViewCreateInfo, pAllocator: ?*const AllocationCallbacks, pView: *BufferView) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateBufferView(device, pCreateInfo, pAllocator, pView));
}
pub fn destroyBufferView(device: Device, bufferView: ?BufferView, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyBufferView(device, bufferView, pAllocator);
}
pub fn createShaderModule(device: Device, pCreateInfo: *const ShaderModuleCreateInfo, pAllocator: ?*const AllocationCallbacks, pShaderModule: *ShaderModule) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateShaderModule(device, pCreateInfo, pAllocator, pShaderModule));
}
pub fn destroyShaderModule(device: Device, shaderModule: ?ShaderModule, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyShaderModule(device, shaderModule, pAllocator);
}
pub fn createPipelineCache(device: Device, pCreateInfo: *const PipelineCacheCreateInfo, pAllocator: ?*const AllocationCallbacks, pPipelineCache: *PipelineCache) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreatePipelineCache(device, pCreateInfo, pAllocator, pPipelineCache));
}
pub fn destroyPipelineCache(device: Device, pipelineCache: ?PipelineCache, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyPipelineCache(device, pipelineCache, pAllocator);
}
pub fn getPipelineCacheData(device: Device, pipelineCache: PipelineCache, pDataSize: ?*u64, pData: ?[*]u8) ResultErr!void {
    return makeError(ResultErr, table.device.vkGetPipelineCacheData(device, pipelineCache, pDataSize, pData));
}
pub fn mergePipelineCaches(device: Device, dstCache: PipelineCache, srcCacheCount: u32, pSrcCaches: [*]const PipelineCache) ResultErr!void {
    return makeError(ResultErr, table.device.vkMergePipelineCaches(device, dstCache, srcCacheCount, pSrcCaches));
}
pub fn createComputePipelines(device: Device, pipelineCache: ?PipelineCache, createInfoCount: u32, pCreateInfos: [*]const ComputePipelineCreateInfo, pAllocator: ?*const AllocationCallbacks, pPipelines: [*]Pipeline) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateComputePipelines(device, pipelineCache, createInfoCount, pCreateInfos, pAllocator, pPipelines));
}
pub fn destroyPipeline(device: Device, pipeline: ?Pipeline, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyPipeline(device, pipeline, pAllocator);
}
pub fn createPipelineLayout(device: Device, pCreateInfo: *const PipelineLayoutCreateInfo, pAllocator: ?*const AllocationCallbacks, pPipelineLayout: *PipelineLayout) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreatePipelineLayout(device, pCreateInfo, pAllocator, pPipelineLayout));
}
pub fn destroyPipelineLayout(device: Device, pipelineLayout: ?PipelineLayout, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyPipelineLayout(device, pipelineLayout, pAllocator);
}
pub fn createSampler(device: Device, pCreateInfo: *const SamplerCreateInfo, pAllocator: ?*const AllocationCallbacks, pSampler: *Sampler) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateSampler(device, pCreateInfo, pAllocator, pSampler));
}
pub fn destroySampler(device: Device, sampler: ?Sampler, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroySampler(device, sampler, pAllocator);
}
pub fn createDescriptorSetLayout(device: Device, pCreateInfo: *const DescriptorSetLayoutCreateInfo, pAllocator: ?*const AllocationCallbacks, pSetLayout: *DescriptorSetLayout) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateDescriptorSetLayout(device, pCreateInfo, pAllocator, pSetLayout));
}
pub fn destroyDescriptorSetLayout(device: Device, descriptorSetLayout: ?DescriptorSetLayout, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyDescriptorSetLayout(device, descriptorSetLayout, pAllocator);
}
pub fn createDescriptorPool(device: Device, pCreateInfo: *const DescriptorPoolCreateInfo, pAllocator: ?*const AllocationCallbacks, pDescriptorPool: *DescriptorPool) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateDescriptorPool(device, pCreateInfo, pAllocator, pDescriptorPool));
}
pub fn destroyDescriptorPool(device: Device, descriptorPool: ?DescriptorPool, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyDescriptorPool(device, descriptorPool, pAllocator);
}
pub fn resetDescriptorPool(device: Device, descriptorPool: DescriptorPool, flags: DescriptorPoolResetFlags) ResultErr!void {
    return makeError(ResultErr, table.device.vkResetDescriptorPool(device, descriptorPool, flags));
}
pub fn allocateDescriptorSets(device: Device, pAllocateInfo: *const DescriptorSetAllocateInfo, pDescriptorSets: [*]DescriptorSet) ResultErr!void {
    return makeError(ResultErr, table.device.vkAllocateDescriptorSets(device, pAllocateInfo, pDescriptorSets));
}
pub fn freeDescriptorSets(device: Device, descriptorPool: DescriptorPool, descriptorSetCount: u32, pDescriptorSets: [*]const DescriptorSet) ResultErr!void {
    return makeError(ResultErr, table.device.vkFreeDescriptorSets(device, descriptorPool, descriptorSetCount, pDescriptorSets));
}
pub fn updateDescriptorSets(device: Device, descriptorWriteCount: u32, pDescriptorWrites: [*]const WriteDescriptorSet, descriptorCopyCount: u32, pDescriptorCopies: [*]const CopyDescriptorSet) void {
    return table.device.vkUpdateDescriptorSets(device, descriptorWriteCount, pDescriptorWrites, descriptorCopyCount, pDescriptorCopies);
}
pub fn cmdBindPipeline(commandBuffer: CommandBuffer, pipelineBindPoint: PipelineBindPoint, pipeline: Pipeline) void {
    return table.device.vkCmdBindPipeline(commandBuffer, pipelineBindPoint, pipeline);
}
pub fn cmdBindDescriptorSets(commandBuffer: CommandBuffer, pipelineBindPoint: PipelineBindPoint, layout: PipelineLayout, firstSet: u32, descriptorSetCount: u32, pDescriptorSets: ?[*]const DescriptorSet, dynamicOffsetCount: u32, pDynamicOffsets: [*]const u32) void {
    return table.device.vkCmdBindDescriptorSets(commandBuffer, pipelineBindPoint, layout, firstSet, descriptorSetCount, pDescriptorSets, dynamicOffsetCount, pDynamicOffsets);
}
pub fn cmdClearColorImage(commandBuffer: CommandBuffer, image: Image, imageLayout: ImageLayout, pColor: *const ClearColorValue, rangeCount: u32, pRanges: [*]const ImageSubresourceRange) void {
    return table.device.vkCmdClearColorImage(commandBuffer, image, imageLayout, pColor, rangeCount, pRanges);
}
pub fn cmdDispatch(commandBuffer: CommandBuffer, groupCountX: u32, groupCountY: u32, groupCountZ: u32) void {
    return table.device.vkCmdDispatch(commandBuffer, groupCountX, groupCountY, groupCountZ);
}
pub fn cmdDispatchIndirect(commandBuffer: CommandBuffer, buffer: Buffer, offset: DeviceSize) void {
    return table.device.vkCmdDispatchIndirect(commandBuffer, buffer, offset);
}
pub fn cmdSetEvent(commandBuffer: CommandBuffer, event: Event, stageMask: PipelineStageFlags) void {
    return table.device.vkCmdSetEvent(commandBuffer, event, stageMask);
}
pub fn cmdResetEvent(commandBuffer: CommandBuffer, event: Event, stageMask: PipelineStageFlags) void {
    return table.device.vkCmdResetEvent(commandBuffer, event, stageMask);
}
pub fn cmdWaitEvents(commandBuffer: CommandBuffer, eventCount: u32, pEvents: [*]const Event, srcStageMask: PipelineStageFlags, dstStageMask: PipelineStageFlags, memoryBarrierCount: u32, pMemoryBarriers: [*]const MemoryBarrier, bufferMemoryBarrierCount: u32, pBufferMemoryBarriers: [*]const BufferMemoryBarrier, imageMemoryBarrierCount: u32, pImageMemoryBarriers: [*]const ImageMemoryBarrier) void {
    return table.device.vkCmdWaitEvents(commandBuffer, eventCount, pEvents, srcStageMask, dstStageMask, memoryBarrierCount, pMemoryBarriers, bufferMemoryBarrierCount, pBufferMemoryBarriers, imageMemoryBarrierCount, pImageMemoryBarriers);
}
pub fn cmdPushConstants(commandBuffer: CommandBuffer, layout: PipelineLayout, stageFlags: ShaderStageFlags, offset: u32, size: u32, pValues: [*]const u8) void {
    return table.device.vkCmdPushConstants(commandBuffer, layout, stageFlags, offset, size, pValues);
}
pub fn createGraphicsPipelines(device: Device, pipelineCache: ?PipelineCache, createInfoCount: u32, pCreateInfos: [*]const GraphicsPipelineCreateInfo, pAllocator: ?*const AllocationCallbacks, pPipelines: [*]Pipeline) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateGraphicsPipelines(device, pipelineCache, createInfoCount, pCreateInfos, pAllocator, pPipelines));
}
pub fn createFramebuffer(device: Device, pCreateInfo: *const FramebufferCreateInfo, pAllocator: ?*const AllocationCallbacks, pFramebuffer: *Framebuffer) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateFramebuffer(device, pCreateInfo, pAllocator, pFramebuffer));
}
pub fn destroyFramebuffer(device: Device, framebuffer: ?Framebuffer, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyFramebuffer(device, framebuffer, pAllocator);
}
pub fn createRenderPass(device: Device, pCreateInfo: *const RenderPassCreateInfo, pAllocator: ?*const AllocationCallbacks, pRenderPass: *RenderPass) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateRenderPass(device, pCreateInfo, pAllocator, pRenderPass));
}
pub fn destroyRenderPass(device: Device, renderPass: ?RenderPass, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyRenderPass(device, renderPass, pAllocator);
}
pub fn getRenderAreaGranularity(device: Device, renderPass: RenderPass, pGranularity: *Extent2D) void {
    return table.device.vkGetRenderAreaGranularity(device, renderPass, pGranularity);
}
pub fn cmdSetViewport(commandBuffer: CommandBuffer, firstViewport: u32, viewportCount: u32, pViewports: [*]const Viewport) void {
    return table.device.vkCmdSetViewport(commandBuffer, firstViewport, viewportCount, pViewports);
}
pub fn cmdSetScissor(commandBuffer: CommandBuffer, firstScissor: u32, scissorCount: u32, pScissors: [*]const Rect2D) void {
    return table.device.vkCmdSetScissor(commandBuffer, firstScissor, scissorCount, pScissors);
}
pub fn cmdSetLineWidth(commandBuffer: CommandBuffer, lineWidth: f32) void {
    return table.device.vkCmdSetLineWidth(commandBuffer, lineWidth);
}
pub fn cmdSetDepthBias(commandBuffer: CommandBuffer, depthBiasConstantFactor: f32, depthBiasClamp: f32, depthBiasSlopeFactor: f32) void {
    return table.device.vkCmdSetDepthBias(commandBuffer, depthBiasConstantFactor, depthBiasClamp, depthBiasSlopeFactor);
}
pub fn cmdSetBlendConstants(commandBuffer: CommandBuffer, blendConstants: [4]f32) void {
    return table.device.vkCmdSetBlendConstants(commandBuffer, blendConstants);
}
pub fn cmdSetDepthBounds(commandBuffer: CommandBuffer, minDepthBounds: f32, maxDepthBounds: f32) void {
    return table.device.vkCmdSetDepthBounds(commandBuffer, minDepthBounds, maxDepthBounds);
}
pub fn cmdSetStencilCompareMask(commandBuffer: CommandBuffer, faceMask: StencilFaceFlags, compareMask: u32) void {
    return table.device.vkCmdSetStencilCompareMask(commandBuffer, faceMask, compareMask);
}
pub fn cmdSetStencilWriteMask(commandBuffer: CommandBuffer, faceMask: StencilFaceFlags, writeMask: u32) void {
    return table.device.vkCmdSetStencilWriteMask(commandBuffer, faceMask, writeMask);
}
pub fn cmdSetStencilReference(commandBuffer: CommandBuffer, faceMask: StencilFaceFlags, reference: u32) void {
    return table.device.vkCmdSetStencilReference(commandBuffer, faceMask, reference);
}
pub fn cmdBindIndexBuffer(commandBuffer: CommandBuffer, buffer: ?Buffer, offset: DeviceSize, indexType: IndexType) void {
    return table.device.vkCmdBindIndexBuffer(commandBuffer, buffer, offset, indexType);
}
pub fn cmdBindVertexBuffers(commandBuffer: CommandBuffer, firstBinding: u32, bindingCount: u32, pBuffers: ?[*]const Buffer, pOffsets: [*]const DeviceSize) void {
    return table.device.vkCmdBindVertexBuffers(commandBuffer, firstBinding, bindingCount, pBuffers, pOffsets);
}
pub fn cmdDraw(commandBuffer: CommandBuffer, vertexCount: u32, instanceCount: u32, firstVertex: u32, firstInstance: u32) void {
    return table.device.vkCmdDraw(commandBuffer, vertexCount, instanceCount, firstVertex, firstInstance);
}
pub fn cmdDrawIndexed(commandBuffer: CommandBuffer, indexCount: u32, instanceCount: u32, firstIndex: u32, vertexOffset: i32, firstInstance: u32) void {
    return table.device.vkCmdDrawIndexed(commandBuffer, indexCount, instanceCount, firstIndex, vertexOffset, firstInstance);
}
pub fn cmdDrawIndirect(commandBuffer: CommandBuffer, buffer: Buffer, offset: DeviceSize, drawCount: u32, stride: u32) void {
    return table.device.vkCmdDrawIndirect(commandBuffer, buffer, offset, drawCount, stride);
}
pub fn cmdDrawIndexedIndirect(commandBuffer: CommandBuffer, buffer: Buffer, offset: DeviceSize, drawCount: u32, stride: u32) void {
    return table.device.vkCmdDrawIndexedIndirect(commandBuffer, buffer, offset, drawCount, stride);
}
pub fn cmdBlitImage(commandBuffer: CommandBuffer, srcImage: Image, srcImageLayout: ImageLayout, dstImage: Image, dstImageLayout: ImageLayout, regionCount: u32, pRegions: [*]const ImageBlit, filter: Filter) void {
    return table.device.vkCmdBlitImage(commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions, filter);
}
pub fn cmdClearDepthStencilImage(commandBuffer: CommandBuffer, image: Image, imageLayout: ImageLayout, pDepthStencil: *const ClearDepthStencilValue, rangeCount: u32, pRanges: [*]const ImageSubresourceRange) void {
    return table.device.vkCmdClearDepthStencilImage(commandBuffer, image, imageLayout, pDepthStencil, rangeCount, pRanges);
}
pub fn cmdClearAttachments(commandBuffer: CommandBuffer, attachmentCount: u32, pAttachments: [*]const ClearAttachment, rectCount: u32, pRects: [*]const ClearRect) void {
    return table.device.vkCmdClearAttachments(commandBuffer, attachmentCount, pAttachments, rectCount, pRects);
}
pub fn cmdResolveImage(commandBuffer: CommandBuffer, srcImage: Image, srcImageLayout: ImageLayout, dstImage: Image, dstImageLayout: ImageLayout, regionCount: u32, pRegions: [*]const ImageResolve) void {
    return table.device.vkCmdResolveImage(commandBuffer, srcImage, srcImageLayout, dstImage, dstImageLayout, regionCount, pRegions);
}
pub fn cmdBeginRenderPass(commandBuffer: CommandBuffer, pRenderPassBegin: *const RenderPassBeginInfo, contents: SubpassContents) void {
    return table.device.vkCmdBeginRenderPass(commandBuffer, pRenderPassBegin, contents);
}
pub fn cmdNextSubpass(commandBuffer: CommandBuffer, contents: SubpassContents) void {
    return table.device.vkCmdNextSubpass(commandBuffer, contents);
}
pub fn cmdEndRenderPass(commandBuffer: CommandBuffer) void {
    return table.device.vkCmdEndRenderPass(commandBuffer);
}
pub fn enumerateInstanceVersion(pApiVersion: *u32) ResultErr!void {
    return makeError(ResultErr, table.global.vkEnumerateInstanceVersion(pApiVersion));
}
pub fn bindBufferMemory2(device: Device, bindInfoCount: u32, pBindInfos: [*]const BindBufferMemoryInfo) ResultErr!void {
    return makeError(ResultErr, table.device.vkBindBufferMemory2(device, bindInfoCount, pBindInfos));
}
pub fn bindImageMemory2(device: Device, bindInfoCount: u32, pBindInfos: [*]const BindImageMemoryInfo) ResultErr!void {
    return makeError(ResultErr, table.device.vkBindImageMemory2(device, bindInfoCount, pBindInfos));
}
pub fn getDeviceGroupPeerMemoryFeatures(device: Device, heapIndex: u32, localDeviceIndex: u32, remoteDeviceIndex: u32, pPeerMemoryFeatures: *PeerMemoryFeatureFlags) void {
    return table.device.vkGetDeviceGroupPeerMemoryFeatures(device, heapIndex, localDeviceIndex, remoteDeviceIndex, pPeerMemoryFeatures);
}
pub fn cmdSetDeviceMask(commandBuffer: CommandBuffer, deviceMask: u32) void {
    return table.device.vkCmdSetDeviceMask(commandBuffer, deviceMask);
}
pub fn enumeratePhysicalDeviceGroups(instance: Instance, pPhysicalDeviceGroupCount: ?*u32, pPhysicalDeviceGroupProperties: ?[*]PhysicalDeviceGroupProperties) ResultErr!void {
    return makeError(ResultErr, table.instance.vkEnumeratePhysicalDeviceGroups(instance, pPhysicalDeviceGroupCount, pPhysicalDeviceGroupProperties));
}
pub fn getImageMemoryRequirements2(device: Device, pInfo: *const ImageMemoryRequirementsInfo2, pMemoryRequirements: *MemoryRequirements2) void {
    return table.device.vkGetImageMemoryRequirements2(device, pInfo, pMemoryRequirements);
}
pub fn getBufferMemoryRequirements2(device: Device, pInfo: *const BufferMemoryRequirementsInfo2, pMemoryRequirements: *MemoryRequirements2) void {
    return table.device.vkGetBufferMemoryRequirements2(device, pInfo, pMemoryRequirements);
}
pub fn getImageSparseMemoryRequirements2(device: Device, pInfo: *const ImageSparseMemoryRequirementsInfo2, pSparseMemoryRequirementCount: ?*u32, pSparseMemoryRequirements: ?[*]SparseImageMemoryRequirements2) void {
    return table.device.vkGetImageSparseMemoryRequirements2(device, pInfo, pSparseMemoryRequirementCount, pSparseMemoryRequirements);
}
pub fn getPhysicalDeviceFeatures2(physicalDevice: PhysicalDevice, pFeatures: *PhysicalDeviceFeatures2) void {
    return table.instance.vkGetPhysicalDeviceFeatures2(physicalDevice, pFeatures);
}
pub fn getPhysicalDeviceProperties2(physicalDevice: PhysicalDevice, pProperties: *PhysicalDeviceProperties2) void {
    return table.instance.vkGetPhysicalDeviceProperties2(physicalDevice, pProperties);
}
pub fn getPhysicalDeviceFormatProperties2(physicalDevice: PhysicalDevice, format: Format, pFormatProperties: *FormatProperties2) void {
    return table.instance.vkGetPhysicalDeviceFormatProperties2(physicalDevice, format, pFormatProperties);
}
pub fn getPhysicalDeviceImageFormatProperties2(physicalDevice: PhysicalDevice, pImageFormatInfo: *const PhysicalDeviceImageFormatInfo2, pImageFormatProperties: *ImageFormatProperties2) ResultErr!void {
    return makeError(ResultErr, table.instance.vkGetPhysicalDeviceImageFormatProperties2(physicalDevice, pImageFormatInfo, pImageFormatProperties));
}
pub fn getPhysicalDeviceQueueFamilyProperties2(physicalDevice: PhysicalDevice, pQueueFamilyPropertyCount: ?*u32, pQueueFamilyProperties: ?[*]QueueFamilyProperties2) void {
    return table.instance.vkGetPhysicalDeviceQueueFamilyProperties2(physicalDevice, pQueueFamilyPropertyCount, pQueueFamilyProperties);
}
pub fn getPhysicalDeviceMemoryProperties2(physicalDevice: PhysicalDevice, pMemoryProperties: *PhysicalDeviceMemoryProperties2) void {
    return table.instance.vkGetPhysicalDeviceMemoryProperties2(physicalDevice, pMemoryProperties);
}
pub fn getPhysicalDeviceSparseImageFormatProperties2(physicalDevice: PhysicalDevice, pFormatInfo: *const PhysicalDeviceSparseImageFormatInfo2, pPropertyCount: ?*u32, pProperties: ?[*]SparseImageFormatProperties2) void {
    return table.instance.vkGetPhysicalDeviceSparseImageFormatProperties2(physicalDevice, pFormatInfo, pPropertyCount, pProperties);
}
pub fn trimCommandPool(device: Device, commandPool: CommandPool, flags: CommandPoolTrimFlags) void {
    return table.device.vkTrimCommandPool(device, commandPool, flags);
}
pub fn getDeviceQueue2(device: Device, pQueueInfo: *const DeviceQueueInfo2, pQueue: *Queue) void {
    return table.device.vkGetDeviceQueue2(device, pQueueInfo, pQueue);
}
pub fn getPhysicalDeviceExternalBufferProperties(physicalDevice: PhysicalDevice, pExternalBufferInfo: *const PhysicalDeviceExternalBufferInfo, pExternalBufferProperties: *ExternalBufferProperties) void {
    return table.instance.vkGetPhysicalDeviceExternalBufferProperties(physicalDevice, pExternalBufferInfo, pExternalBufferProperties);
}
pub fn getPhysicalDeviceExternalFenceProperties(physicalDevice: PhysicalDevice, pExternalFenceInfo: *const PhysicalDeviceExternalFenceInfo, pExternalFenceProperties: *ExternalFenceProperties) void {
    return table.instance.vkGetPhysicalDeviceExternalFenceProperties(physicalDevice, pExternalFenceInfo, pExternalFenceProperties);
}
pub fn getPhysicalDeviceExternalSemaphoreProperties(physicalDevice: PhysicalDevice, pExternalSemaphoreInfo: *const PhysicalDeviceExternalSemaphoreInfo, pExternalSemaphoreProperties: *ExternalSemaphoreProperties) void {
    return table.instance.vkGetPhysicalDeviceExternalSemaphoreProperties(physicalDevice, pExternalSemaphoreInfo, pExternalSemaphoreProperties);
}
pub fn cmdDispatchBase(commandBuffer: CommandBuffer, baseGroupX: u32, baseGroupY: u32, baseGroupZ: u32, groupCountX: u32, groupCountY: u32, groupCountZ: u32) void {
    return table.device.vkCmdDispatchBase(commandBuffer, baseGroupX, baseGroupY, baseGroupZ, groupCountX, groupCountY, groupCountZ);
}
pub fn createDescriptorUpdateTemplate(device: Device, pCreateInfo: *const DescriptorUpdateTemplateCreateInfo, pAllocator: ?*const AllocationCallbacks, pDescriptorUpdateTemplate: *DescriptorUpdateTemplate) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateDescriptorUpdateTemplate(device, pCreateInfo, pAllocator, pDescriptorUpdateTemplate));
}
pub fn destroyDescriptorUpdateTemplate(device: Device, descriptorUpdateTemplate: ?DescriptorUpdateTemplate, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyDescriptorUpdateTemplate(device, descriptorUpdateTemplate, pAllocator);
}
pub fn updateDescriptorSetWithTemplate(device: Device, descriptorSet: DescriptorSet, descriptorUpdateTemplate: DescriptorUpdateTemplate, pData: *const anyopaque) void {
    return table.device.vkUpdateDescriptorSetWithTemplate(device, descriptorSet, descriptorUpdateTemplate, pData);
}
pub fn getDescriptorSetLayoutSupport(device: Device, pCreateInfo: *const DescriptorSetLayoutCreateInfo, pSupport: *DescriptorSetLayoutSupport) void {
    return table.device.vkGetDescriptorSetLayoutSupport(device, pCreateInfo, pSupport);
}
pub fn createSamplerYcbcrConversion(device: Device, pCreateInfo: *const SamplerYcbcrConversionCreateInfo, pAllocator: ?*const AllocationCallbacks, pYcbcrConversion: *SamplerYcbcrConversion) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateSamplerYcbcrConversion(device, pCreateInfo, pAllocator, pYcbcrConversion));
}
pub fn destroySamplerYcbcrConversion(device: Device, ycbcrConversion: ?SamplerYcbcrConversion, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroySamplerYcbcrConversion(device, ycbcrConversion, pAllocator);
}
pub fn resetQueryPool(device: Device, queryPool: QueryPool, firstQuery: u32, queryCount: u32) void {
    return table.device.vkResetQueryPool(device, queryPool, firstQuery, queryCount);
}
pub fn getSemaphoreCounterValue(device: Device, semaphore: Semaphore, pValue: *u64) ResultErr!void {
    return makeError(ResultErr, table.device.vkGetSemaphoreCounterValue(device, semaphore, pValue));
}
pub fn waitSemaphores(device: Device, pWaitInfo: *const SemaphoreWaitInfo, timeout: u64) ResultErr!void {
    return makeError(ResultErr, table.device.vkWaitSemaphores(device, pWaitInfo, timeout));
}
pub fn signalSemaphore(device: Device, pSignalInfo: *const SemaphoreSignalInfo) ResultErr!void {
    return makeError(ResultErr, table.device.vkSignalSemaphore(device, pSignalInfo));
}
pub fn getBufferDeviceAddress(device: Device, pInfo: *const BufferDeviceAddressInfo) DeviceAddress {
    return table.device.vkGetBufferDeviceAddress(device, pInfo);
}
pub fn getBufferOpaqueCaptureAddress(device: Device, pInfo: *const BufferDeviceAddressInfo) u64 {
    return table.device.vkGetBufferOpaqueCaptureAddress(device, pInfo);
}
pub fn getDeviceMemoryOpaqueCaptureAddress(device: Device, pInfo: *const DeviceMemoryOpaqueCaptureAddressInfo) u64 {
    return table.device.vkGetDeviceMemoryOpaqueCaptureAddress(device, pInfo);
}
pub fn cmdDrawIndirectCount(commandBuffer: CommandBuffer, buffer: Buffer, offset: DeviceSize, countBuffer: Buffer, countBufferOffset: DeviceSize, maxDrawCount: u32, stride: u32) void {
    return table.device.vkCmdDrawIndirectCount(commandBuffer, buffer, offset, countBuffer, countBufferOffset, maxDrawCount, stride);
}
pub fn cmdDrawIndexedIndirectCount(commandBuffer: CommandBuffer, buffer: Buffer, offset: DeviceSize, countBuffer: Buffer, countBufferOffset: DeviceSize, maxDrawCount: u32, stride: u32) void {
    return table.device.vkCmdDrawIndexedIndirectCount(commandBuffer, buffer, offset, countBuffer, countBufferOffset, maxDrawCount, stride);
}
pub fn createRenderPass2(device: Device, pCreateInfo: *const RenderPassCreateInfo2, pAllocator: ?*const AllocationCallbacks, pRenderPass: *RenderPass) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateRenderPass2(device, pCreateInfo, pAllocator, pRenderPass));
}
pub fn cmdBeginRenderPass2(commandBuffer: CommandBuffer, pRenderPassBegin: *const RenderPassBeginInfo, pSubpassBeginInfo: *const SubpassBeginInfo) void {
    return table.device.vkCmdBeginRenderPass2(commandBuffer, pRenderPassBegin, pSubpassBeginInfo);
}
pub fn cmdNextSubpass2(commandBuffer: CommandBuffer, pSubpassBeginInfo: *const SubpassBeginInfo, pSubpassEndInfo: *const SubpassEndInfo) void {
    return table.device.vkCmdNextSubpass2(commandBuffer, pSubpassBeginInfo, pSubpassEndInfo);
}
pub fn cmdEndRenderPass2(commandBuffer: CommandBuffer, pSubpassEndInfo: *const SubpassEndInfo) void {
    return table.device.vkCmdEndRenderPass2(commandBuffer, pSubpassEndInfo);
}
pub fn getPhysicalDeviceToolProperties(physicalDevice: PhysicalDevice, pToolCount: ?*u32, pToolProperties: ?[*]PhysicalDeviceToolProperties) ResultErr!void {
    return makeError(ResultErr, table.instance.vkGetPhysicalDeviceToolProperties(physicalDevice, pToolCount, pToolProperties));
}
pub fn createPrivateDataSlot(device: Device, pCreateInfo: *const PrivateDataSlotCreateInfo, pAllocator: ?*const AllocationCallbacks, pPrivateDataSlot: *PrivateDataSlot) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreatePrivateDataSlot(device, pCreateInfo, pAllocator, pPrivateDataSlot));
}
pub fn destroyPrivateDataSlot(device: Device, privateDataSlot: ?PrivateDataSlot, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroyPrivateDataSlot(device, privateDataSlot, pAllocator);
}
pub fn setPrivateData(device: Device, objectType: ObjectType, objectHandle: u64, privateDataSlot: PrivateDataSlot, data: u64) ResultErr!void {
    return makeError(ResultErr, table.device.vkSetPrivateData(device, objectType, objectHandle, privateDataSlot, data));
}
pub fn getPrivateData(device: Device, objectType: ObjectType, objectHandle: u64, privateDataSlot: PrivateDataSlot, pData: *u64) void {
    return table.device.vkGetPrivateData(device, objectType, objectHandle, privateDataSlot, pData);
}
pub fn cmdPipelineBarrier2(commandBuffer: CommandBuffer, pDependencyInfo: *const DependencyInfo) void {
    return table.device.vkCmdPipelineBarrier2(commandBuffer, pDependencyInfo);
}
pub fn cmdWriteTimestamp2(commandBuffer: CommandBuffer, stage: PipelineStageFlags2, queryPool: QueryPool, query: u32) void {
    return table.device.vkCmdWriteTimestamp2(commandBuffer, stage, queryPool, query);
}
pub fn queueSubmit2(queue: Queue, submitCount: u32, pSubmits: [*]const SubmitInfo2, fence: ?Fence) ResultErr!void {
    return makeError(ResultErr, table.device.vkQueueSubmit2(queue, submitCount, pSubmits, fence));
}
pub fn cmdCopyBuffer2(commandBuffer: CommandBuffer, pCopyBufferInfo: *const CopyBufferInfo2) void {
    return table.device.vkCmdCopyBuffer2(commandBuffer, pCopyBufferInfo);
}
pub fn cmdCopyImage2(commandBuffer: CommandBuffer, pCopyImageInfo: *const CopyImageInfo2) void {
    return table.device.vkCmdCopyImage2(commandBuffer, pCopyImageInfo);
}
pub fn cmdCopyBufferToImage2(commandBuffer: CommandBuffer, pCopyBufferToImageInfo: *const CopyBufferToImageInfo2) void {
    return table.device.vkCmdCopyBufferToImage2(commandBuffer, pCopyBufferToImageInfo);
}
pub fn cmdCopyImageToBuffer2(commandBuffer: CommandBuffer, pCopyImageToBufferInfo: *const CopyImageToBufferInfo2) void {
    return table.device.vkCmdCopyImageToBuffer2(commandBuffer, pCopyImageToBufferInfo);
}
pub fn getDeviceBufferMemoryRequirements(device: Device, pInfo: *const DeviceBufferMemoryRequirements, pMemoryRequirements: *MemoryRequirements2) void {
    return table.device.vkGetDeviceBufferMemoryRequirements(device, pInfo, pMemoryRequirements);
}
pub fn getDeviceImageMemoryRequirements(device: Device, pInfo: *const DeviceImageMemoryRequirements, pMemoryRequirements: *MemoryRequirements2) void {
    return table.device.vkGetDeviceImageMemoryRequirements(device, pInfo, pMemoryRequirements);
}
pub fn getDeviceImageSparseMemoryRequirements(device: Device, pInfo: *const DeviceImageMemoryRequirements, pSparseMemoryRequirementCount: ?*u32, pSparseMemoryRequirements: ?[*]SparseImageMemoryRequirements2) void {
    return table.device.vkGetDeviceImageSparseMemoryRequirements(device, pInfo, pSparseMemoryRequirementCount, pSparseMemoryRequirements);
}
pub fn cmdSetEvent2(commandBuffer: CommandBuffer, event: Event, pDependencyInfo: *const DependencyInfo) void {
    return table.device.vkCmdSetEvent2(commandBuffer, event, pDependencyInfo);
}
pub fn cmdResetEvent2(commandBuffer: CommandBuffer, event: Event, stageMask: PipelineStageFlags2) void {
    return table.device.vkCmdResetEvent2(commandBuffer, event, stageMask);
}
pub fn cmdWaitEvents2(commandBuffer: CommandBuffer, eventCount: u32, pEvents: [*]const Event, pDependencyInfos: [*]const DependencyInfo) void {
    return table.device.vkCmdWaitEvents2(commandBuffer, eventCount, pEvents, pDependencyInfos);
}
pub fn cmdBlitImage2(commandBuffer: CommandBuffer, pBlitImageInfo: *const BlitImageInfo2) void {
    return table.device.vkCmdBlitImage2(commandBuffer, pBlitImageInfo);
}
pub fn cmdResolveImage2(commandBuffer: CommandBuffer, pResolveImageInfo: *const ResolveImageInfo2) void {
    return table.device.vkCmdResolveImage2(commandBuffer, pResolveImageInfo);
}
pub fn cmdBeginRendering(commandBuffer: CommandBuffer, pRenderingInfo: *const RenderingInfo) void {
    return table.device.vkCmdBeginRendering(commandBuffer, pRenderingInfo);
}
pub fn cmdEndRendering(commandBuffer: CommandBuffer) void {
    return table.device.vkCmdEndRendering(commandBuffer);
}
pub fn cmdSetCullMode(commandBuffer: CommandBuffer, cullMode: CullModeFlags) void {
    return table.device.vkCmdSetCullMode(commandBuffer, cullMode);
}
pub fn cmdSetFrontFace(commandBuffer: CommandBuffer, frontFace: FrontFace) void {
    return table.device.vkCmdSetFrontFace(commandBuffer, frontFace);
}
pub fn cmdSetPrimitiveTopology(commandBuffer: CommandBuffer, primitiveTopology: PrimitiveTopology) void {
    return table.device.vkCmdSetPrimitiveTopology(commandBuffer, primitiveTopology);
}
pub fn cmdSetViewportWithCount(commandBuffer: CommandBuffer, viewportCount: u32, pViewports: [*]const Viewport) void {
    return table.device.vkCmdSetViewportWithCount(commandBuffer, viewportCount, pViewports);
}
pub fn cmdSetScissorWithCount(commandBuffer: CommandBuffer, scissorCount: u32, pScissors: [*]const Rect2D) void {
    return table.device.vkCmdSetScissorWithCount(commandBuffer, scissorCount, pScissors);
}
pub fn cmdBindVertexBuffers2(commandBuffer: CommandBuffer, firstBinding: u32, bindingCount: u32, pBuffers: ?[*]const Buffer, pOffsets: [*]const DeviceSize, pSizes: ?[*]const DeviceSize, pStrides: ?[*]const DeviceSize) void {
    return table.device.vkCmdBindVertexBuffers2(commandBuffer, firstBinding, bindingCount, pBuffers, pOffsets, pSizes, pStrides);
}
pub fn cmdSetDepthTestEnable(commandBuffer: CommandBuffer, depthTestEnable: Bool) void {
    return table.device.vkCmdSetDepthTestEnable(commandBuffer, depthTestEnable);
}
pub fn cmdSetDepthWriteEnable(commandBuffer: CommandBuffer, depthWriteEnable: Bool) void {
    return table.device.vkCmdSetDepthWriteEnable(commandBuffer, depthWriteEnable);
}
pub fn cmdSetDepthCompareOp(commandBuffer: CommandBuffer, depthCompareOp: CompareOp) void {
    return table.device.vkCmdSetDepthCompareOp(commandBuffer, depthCompareOp);
}
pub fn cmdSetDepthBoundsTestEnable(commandBuffer: CommandBuffer, depthBoundsTestEnable: Bool) void {
    return table.device.vkCmdSetDepthBoundsTestEnable(commandBuffer, depthBoundsTestEnable);
}
pub fn cmdSetStencilTestEnable(commandBuffer: CommandBuffer, stencilTestEnable: Bool) void {
    return table.device.vkCmdSetStencilTestEnable(commandBuffer, stencilTestEnable);
}
pub fn cmdSetStencilOp(commandBuffer: CommandBuffer, faceMask: StencilFaceFlags, failOp: StencilOp, passOp: StencilOp, depthFailOp: StencilOp, compareOp: CompareOp) void {
    return table.device.vkCmdSetStencilOp(commandBuffer, faceMask, failOp, passOp, depthFailOp, compareOp);
}
pub fn cmdSetRasterizerDiscardEnable(commandBuffer: CommandBuffer, rasterizerDiscardEnable: Bool) void {
    return table.device.vkCmdSetRasterizerDiscardEnable(commandBuffer, rasterizerDiscardEnable);
}
pub fn cmdSetDepthBiasEnable(commandBuffer: CommandBuffer, depthBiasEnable: Bool) void {
    return table.device.vkCmdSetDepthBiasEnable(commandBuffer, depthBiasEnable);
}
pub fn cmdSetPrimitiveRestartEnable(commandBuffer: CommandBuffer, primitiveRestartEnable: Bool) void {
    return table.device.vkCmdSetPrimitiveRestartEnable(commandBuffer, primitiveRestartEnable);
}
pub fn destroySurfaceKHR(instance: Instance, surface: ?SurfaceKHR, pAllocator: ?*const AllocationCallbacks) void {
    return table.instance.vkDestroySurfaceKHR(instance, surface, pAllocator);
}
pub fn getPhysicalDeviceSurfaceSupportKHR(physicalDevice: PhysicalDevice, queueFamilyIndex: u32, surface: SurfaceKHR, pSupported: *Bool) ResultErr!void {
    return makeError(ResultErr, table.instance.vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, queueFamilyIndex, surface, pSupported));
}
pub fn getPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice: PhysicalDevice, surface: SurfaceKHR, pSurfaceCapabilities: *SurfaceCapabilitiesKHR) ResultErr!void {
    return makeError(ResultErr, table.instance.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, pSurfaceCapabilities));
}
pub fn getPhysicalDeviceSurfaceFormatsKHR(physicalDevice: PhysicalDevice, surface: ?SurfaceKHR, pSurfaceFormatCount: ?*u32, pSurfaceFormats: ?[*]SurfaceFormatKHR) ResultErr!void {
    return makeError(ResultErr, table.instance.vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, pSurfaceFormatCount, pSurfaceFormats));
}
pub fn getPhysicalDeviceSurfacePresentModesKHR(physicalDevice: PhysicalDevice, surface: ?SurfaceKHR, pPresentModeCount: ?*u32, pPresentModes: ?[*]PresentModeKHR) ResultErr!void {
    return makeError(ResultErr, table.instance.vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, pPresentModeCount, pPresentModes));
}
pub fn createSwapchainKHR(device: Device, pCreateInfo: *const SwapchainCreateInfoKHR, pAllocator: ?*const AllocationCallbacks, pSwapchain: *SwapchainKHR) ResultErr!void {
    return makeError(ResultErr, table.device.vkCreateSwapchainKHR(device, pCreateInfo, pAllocator, pSwapchain));
}
pub fn destroySwapchainKHR(device: Device, swapchain: ?SwapchainKHR, pAllocator: ?*const AllocationCallbacks) void {
    return table.device.vkDestroySwapchainKHR(device, swapchain, pAllocator);
}
pub fn getSwapchainImagesKHR(device: Device, swapchain: SwapchainKHR, pSwapchainImageCount: ?*u32, pSwapchainImages: ?[*]Image) ResultErr!void {
    return makeError(ResultErr, table.device.vkGetSwapchainImagesKHR(device, swapchain, pSwapchainImageCount, pSwapchainImages));
}
pub fn acquireNextImageKHR(device: Device, swapchain: SwapchainKHR, timeout: u64, semaphore: ?Semaphore, fence: ?Fence, pImageIndex: *u32) ResultErr!void {
    return makeError(ResultErr, table.device.vkAcquireNextImageKHR(device, swapchain, timeout, semaphore, fence, pImageIndex));
}
pub fn queuePresentKHR(queue: Queue, pPresentInfo: *const PresentInfoKHR) ResultErr!void {
    return makeError(ResultErr, table.device.vkQueuePresentKHR(queue, pPresentInfo));
}
pub fn getDeviceGroupPresentCapabilitiesKHR(device: Device, pDeviceGroupPresentCapabilities: *DeviceGroupPresentCapabilitiesKHR) ResultErr!void {
    return makeError(ResultErr, table.device.vkGetDeviceGroupPresentCapabilitiesKHR(device, pDeviceGroupPresentCapabilities));
}
pub fn getDeviceGroupSurfacePresentModesKHR(device: Device, surface: SurfaceKHR, pModes: ?*DeviceGroupPresentModeFlagsKHR) ResultErr!void {
    return makeError(ResultErr, table.device.vkGetDeviceGroupSurfacePresentModesKHR(device, surface, pModes));
}
pub fn getPhysicalDevicePresentRectanglesKHR(physicalDevice: PhysicalDevice, surface: SurfaceKHR, pRectCount: ?*u32, pRects: ?[*]Rect2D) ResultErr!void {
    return makeError(ResultErr, table.instance.vkGetPhysicalDevicePresentRectanglesKHR(physicalDevice, surface, pRectCount, pRects));
}
pub fn acquireNextImage2KHR(device: Device, pAcquireInfo: *const AcquireNextImageInfoKHR, pImageIndex: *u32) ResultErr!void {
    return makeError(ResultErr, table.device.vkAcquireNextImage2KHR(device, pAcquireInfo, pImageIndex));
}
pub fn setDebugUtilsObjectNameEXT(device: Device, pNameInfo: *const DebugUtilsObjectNameInfoEXT) ResultErr!void {
    return makeError(ResultErr, table.device.vkSetDebugUtilsObjectNameEXT(device, pNameInfo));
}
pub fn setDebugUtilsObjectTagEXT(device: Device, pTagInfo: *const DebugUtilsObjectTagInfoEXT) ResultErr!void {
    return makeError(ResultErr, table.device.vkSetDebugUtilsObjectTagEXT(device, pTagInfo));
}
pub fn queueBeginDebugUtilsLabelEXT(queue: Queue, pLabelInfo: *const DebugUtilsLabelEXT) void {
    return table.device.vkQueueBeginDebugUtilsLabelEXT(queue, pLabelInfo);
}
pub fn queueEndDebugUtilsLabelEXT(queue: Queue) void {
    return table.device.vkQueueEndDebugUtilsLabelEXT(queue);
}
pub fn queueInsertDebugUtilsLabelEXT(queue: Queue, pLabelInfo: *const DebugUtilsLabelEXT) void {
    return table.device.vkQueueInsertDebugUtilsLabelEXT(queue, pLabelInfo);
}
pub fn cmdBeginDebugUtilsLabelEXT(commandBuffer: CommandBuffer, pLabelInfo: *const DebugUtilsLabelEXT) void {
    return table.device.vkCmdBeginDebugUtilsLabelEXT(commandBuffer, pLabelInfo);
}
pub fn cmdEndDebugUtilsLabelEXT(commandBuffer: CommandBuffer) void {
    return table.device.vkCmdEndDebugUtilsLabelEXT(commandBuffer);
}
pub fn cmdInsertDebugUtilsLabelEXT(commandBuffer: CommandBuffer, pLabelInfo: *const DebugUtilsLabelEXT) void {
    return table.device.vkCmdInsertDebugUtilsLabelEXT(commandBuffer, pLabelInfo);
}
pub fn createDebugUtilsMessengerEXT(instance: Instance, pCreateInfo: *const DebugUtilsMessengerCreateInfoEXT, pAllocator: ?*const AllocationCallbacks, pMessenger: *DebugUtilsMessengerEXT) ResultErr!void {
    return makeError(ResultErr, table.instance.vkCreateDebugUtilsMessengerEXT(instance, pCreateInfo, pAllocator, pMessenger));
}
pub fn destroyDebugUtilsMessengerEXT(instance: Instance, messenger: ?DebugUtilsMessengerEXT, pAllocator: ?*const AllocationCallbacks) void {
    return table.instance.vkDestroyDebugUtilsMessengerEXT(instance, messenger, pAllocator);
}
pub fn submitDebugUtilsMessageEXT(instance: Instance, messageSeverity: DebugUtilsMessageSeverityFlagsEXT, messageTypes: DebugUtilsMessageTypeFlagsEXT, pCallbackData: *const DebugUtilsMessengerCallbackDataEXT) void {
    return table.instance.vkSubmitDebugUtilsMessageEXT(instance, messageSeverity, messageTypes, pCallbackData);
}

pub const table = struct {
    pub const global = struct {
        pub var vkCreateInstance: pfn.vkCreateInstance = undefined;
        pub var vkEnumerateInstanceExtensionProperties: pfn.vkEnumerateInstanceExtensionProperties = undefined;
        pub var vkEnumerateInstanceLayerProperties: pfn.vkEnumerateInstanceLayerProperties = undefined;
        pub var vkEnumerateInstanceVersion: pfn.vkEnumerateInstanceVersion = undefined;
    };
    pub const instance = struct {
        pub var vkDestroyInstance: pfn.vkDestroyInstance = undefined;
        pub var vkEnumeratePhysicalDevices: pfn.vkEnumeratePhysicalDevices = undefined;
        pub var vkGetPhysicalDeviceFeatures: pfn.vkGetPhysicalDeviceFeatures = undefined;
        pub var vkGetPhysicalDeviceFormatProperties: pfn.vkGetPhysicalDeviceFormatProperties = undefined;
        pub var vkGetPhysicalDeviceImageFormatProperties: pfn.vkGetPhysicalDeviceImageFormatProperties = undefined;
        pub var vkGetPhysicalDeviceProperties: pfn.vkGetPhysicalDeviceProperties = undefined;
        pub var vkGetPhysicalDeviceQueueFamilyProperties: pfn.vkGetPhysicalDeviceQueueFamilyProperties = undefined;
        pub var vkGetPhysicalDeviceMemoryProperties: pfn.vkGetPhysicalDeviceMemoryProperties = undefined;
        pub var vkGetInstanceProcAddr: pfn.vkGetInstanceProcAddr = undefined;
        pub var vkCreateDevice: pfn.vkCreateDevice = undefined;
        pub var vkEnumerateDeviceExtensionProperties: pfn.vkEnumerateDeviceExtensionProperties = undefined;
        pub var vkEnumerateDeviceLayerProperties: pfn.vkEnumerateDeviceLayerProperties = undefined;
        pub var vkGetPhysicalDeviceSparseImageFormatProperties: pfn.vkGetPhysicalDeviceSparseImageFormatProperties = undefined;
        pub var vkEnumeratePhysicalDeviceGroups: pfn.vkEnumeratePhysicalDeviceGroups = undefined;
        pub var vkGetPhysicalDeviceFeatures2: pfn.vkGetPhysicalDeviceFeatures2 = undefined;
        pub var vkGetPhysicalDeviceProperties2: pfn.vkGetPhysicalDeviceProperties2 = undefined;
        pub var vkGetPhysicalDeviceFormatProperties2: pfn.vkGetPhysicalDeviceFormatProperties2 = undefined;
        pub var vkGetPhysicalDeviceImageFormatProperties2: pfn.vkGetPhysicalDeviceImageFormatProperties2 = undefined;
        pub var vkGetPhysicalDeviceQueueFamilyProperties2: pfn.vkGetPhysicalDeviceQueueFamilyProperties2 = undefined;
        pub var vkGetPhysicalDeviceMemoryProperties2: pfn.vkGetPhysicalDeviceMemoryProperties2 = undefined;
        pub var vkGetPhysicalDeviceSparseImageFormatProperties2: pfn.vkGetPhysicalDeviceSparseImageFormatProperties2 = undefined;
        pub var vkGetPhysicalDeviceExternalBufferProperties: pfn.vkGetPhysicalDeviceExternalBufferProperties = undefined;
        pub var vkGetPhysicalDeviceExternalFenceProperties: pfn.vkGetPhysicalDeviceExternalFenceProperties = undefined;
        pub var vkGetPhysicalDeviceExternalSemaphoreProperties: pfn.vkGetPhysicalDeviceExternalSemaphoreProperties = undefined;
        pub var vkGetPhysicalDeviceToolProperties: pfn.vkGetPhysicalDeviceToolProperties = undefined;
        pub var vkDestroySurfaceKHR: pfn.vkDestroySurfaceKHR = undefined;
        pub var vkGetPhysicalDeviceSurfaceSupportKHR: pfn.vkGetPhysicalDeviceSurfaceSupportKHR = undefined;
        pub var vkGetPhysicalDeviceSurfaceCapabilitiesKHR: pfn.vkGetPhysicalDeviceSurfaceCapabilitiesKHR = undefined;
        pub var vkGetPhysicalDeviceSurfaceFormatsKHR: pfn.vkGetPhysicalDeviceSurfaceFormatsKHR = undefined;
        pub var vkGetPhysicalDeviceSurfacePresentModesKHR: pfn.vkGetPhysicalDeviceSurfacePresentModesKHR = undefined;
        pub var vkGetPhysicalDevicePresentRectanglesKHR: pfn.vkGetPhysicalDevicePresentRectanglesKHR = undefined;
        pub var vkCreateDebugUtilsMessengerEXT: pfn.vkCreateDebugUtilsMessengerEXT = undefined;
        pub var vkDestroyDebugUtilsMessengerEXT: pfn.vkDestroyDebugUtilsMessengerEXT = undefined;
        pub var vkSubmitDebugUtilsMessageEXT: pfn.vkSubmitDebugUtilsMessageEXT = undefined;
    };
    pub const device = struct {
        pub var vkGetDeviceProcAddr: pfn.vkGetDeviceProcAddr = undefined;
        pub var vkDestroyDevice: pfn.vkDestroyDevice = undefined;
        pub var vkGetDeviceQueue: pfn.vkGetDeviceQueue = undefined;
        pub var vkQueueSubmit: pfn.vkQueueSubmit = undefined;
        pub var vkQueueWaitIdle: pfn.vkQueueWaitIdle = undefined;
        pub var vkDeviceWaitIdle: pfn.vkDeviceWaitIdle = undefined;
        pub var vkAllocateMemory: pfn.vkAllocateMemory = undefined;
        pub var vkFreeMemory: pfn.vkFreeMemory = undefined;
        pub var vkMapMemory: pfn.vkMapMemory = undefined;
        pub var vkUnmapMemory: pfn.vkUnmapMemory = undefined;
        pub var vkFlushMappedMemoryRanges: pfn.vkFlushMappedMemoryRanges = undefined;
        pub var vkInvalidateMappedMemoryRanges: pfn.vkInvalidateMappedMemoryRanges = undefined;
        pub var vkGetDeviceMemoryCommitment: pfn.vkGetDeviceMemoryCommitment = undefined;
        pub var vkBindBufferMemory: pfn.vkBindBufferMemory = undefined;
        pub var vkBindImageMemory: pfn.vkBindImageMemory = undefined;
        pub var vkGetBufferMemoryRequirements: pfn.vkGetBufferMemoryRequirements = undefined;
        pub var vkGetImageMemoryRequirements: pfn.vkGetImageMemoryRequirements = undefined;
        pub var vkGetImageSparseMemoryRequirements: pfn.vkGetImageSparseMemoryRequirements = undefined;
        pub var vkQueueBindSparse: pfn.vkQueueBindSparse = undefined;
        pub var vkCreateFence: pfn.vkCreateFence = undefined;
        pub var vkDestroyFence: pfn.vkDestroyFence = undefined;
        pub var vkResetFences: pfn.vkResetFences = undefined;
        pub var vkGetFenceStatus: pfn.vkGetFenceStatus = undefined;
        pub var vkWaitForFences: pfn.vkWaitForFences = undefined;
        pub var vkCreateSemaphore: pfn.vkCreateSemaphore = undefined;
        pub var vkDestroySemaphore: pfn.vkDestroySemaphore = undefined;
        pub var vkCreateQueryPool: pfn.vkCreateQueryPool = undefined;
        pub var vkDestroyQueryPool: pfn.vkDestroyQueryPool = undefined;
        pub var vkGetQueryPoolResults: pfn.vkGetQueryPoolResults = undefined;
        pub var vkCreateBuffer: pfn.vkCreateBuffer = undefined;
        pub var vkDestroyBuffer: pfn.vkDestroyBuffer = undefined;
        pub var vkCreateImage: pfn.vkCreateImage = undefined;
        pub var vkDestroyImage: pfn.vkDestroyImage = undefined;
        pub var vkGetImageSubresourceLayout: pfn.vkGetImageSubresourceLayout = undefined;
        pub var vkCreateImageView: pfn.vkCreateImageView = undefined;
        pub var vkDestroyImageView: pfn.vkDestroyImageView = undefined;
        pub var vkCreateCommandPool: pfn.vkCreateCommandPool = undefined;
        pub var vkDestroyCommandPool: pfn.vkDestroyCommandPool = undefined;
        pub var vkResetCommandPool: pfn.vkResetCommandPool = undefined;
        pub var vkAllocateCommandBuffers: pfn.vkAllocateCommandBuffers = undefined;
        pub var vkFreeCommandBuffers: pfn.vkFreeCommandBuffers = undefined;
        pub var vkBeginCommandBuffer: pfn.vkBeginCommandBuffer = undefined;
        pub var vkEndCommandBuffer: pfn.vkEndCommandBuffer = undefined;
        pub var vkResetCommandBuffer: pfn.vkResetCommandBuffer = undefined;
        pub var vkCmdCopyBuffer: pfn.vkCmdCopyBuffer = undefined;
        pub var vkCmdCopyImage: pfn.vkCmdCopyImage = undefined;
        pub var vkCmdCopyBufferToImage: pfn.vkCmdCopyBufferToImage = undefined;
        pub var vkCmdCopyImageToBuffer: pfn.vkCmdCopyImageToBuffer = undefined;
        pub var vkCmdUpdateBuffer: pfn.vkCmdUpdateBuffer = undefined;
        pub var vkCmdFillBuffer: pfn.vkCmdFillBuffer = undefined;
        pub var vkCmdPipelineBarrier: pfn.vkCmdPipelineBarrier = undefined;
        pub var vkCmdBeginQuery: pfn.vkCmdBeginQuery = undefined;
        pub var vkCmdEndQuery: pfn.vkCmdEndQuery = undefined;
        pub var vkCmdResetQueryPool: pfn.vkCmdResetQueryPool = undefined;
        pub var vkCmdWriteTimestamp: pfn.vkCmdWriteTimestamp = undefined;
        pub var vkCmdCopyQueryPoolResults: pfn.vkCmdCopyQueryPoolResults = undefined;
        pub var vkCmdExecuteCommands: pfn.vkCmdExecuteCommands = undefined;
        pub var vkCreateEvent: pfn.vkCreateEvent = undefined;
        pub var vkDestroyEvent: pfn.vkDestroyEvent = undefined;
        pub var vkGetEventStatus: pfn.vkGetEventStatus = undefined;
        pub var vkSetEvent: pfn.vkSetEvent = undefined;
        pub var vkResetEvent: pfn.vkResetEvent = undefined;
        pub var vkCreateBufferView: pfn.vkCreateBufferView = undefined;
        pub var vkDestroyBufferView: pfn.vkDestroyBufferView = undefined;
        pub var vkCreateShaderModule: pfn.vkCreateShaderModule = undefined;
        pub var vkDestroyShaderModule: pfn.vkDestroyShaderModule = undefined;
        pub var vkCreatePipelineCache: pfn.vkCreatePipelineCache = undefined;
        pub var vkDestroyPipelineCache: pfn.vkDestroyPipelineCache = undefined;
        pub var vkGetPipelineCacheData: pfn.vkGetPipelineCacheData = undefined;
        pub var vkMergePipelineCaches: pfn.vkMergePipelineCaches = undefined;
        pub var vkCreateComputePipelines: pfn.vkCreateComputePipelines = undefined;
        pub var vkDestroyPipeline: pfn.vkDestroyPipeline = undefined;
        pub var vkCreatePipelineLayout: pfn.vkCreatePipelineLayout = undefined;
        pub var vkDestroyPipelineLayout: pfn.vkDestroyPipelineLayout = undefined;
        pub var vkCreateSampler: pfn.vkCreateSampler = undefined;
        pub var vkDestroySampler: pfn.vkDestroySampler = undefined;
        pub var vkCreateDescriptorSetLayout: pfn.vkCreateDescriptorSetLayout = undefined;
        pub var vkDestroyDescriptorSetLayout: pfn.vkDestroyDescriptorSetLayout = undefined;
        pub var vkCreateDescriptorPool: pfn.vkCreateDescriptorPool = undefined;
        pub var vkDestroyDescriptorPool: pfn.vkDestroyDescriptorPool = undefined;
        pub var vkResetDescriptorPool: pfn.vkResetDescriptorPool = undefined;
        pub var vkAllocateDescriptorSets: pfn.vkAllocateDescriptorSets = undefined;
        pub var vkFreeDescriptorSets: pfn.vkFreeDescriptorSets = undefined;
        pub var vkUpdateDescriptorSets: pfn.vkUpdateDescriptorSets = undefined;
        pub var vkCmdBindPipeline: pfn.vkCmdBindPipeline = undefined;
        pub var vkCmdBindDescriptorSets: pfn.vkCmdBindDescriptorSets = undefined;
        pub var vkCmdClearColorImage: pfn.vkCmdClearColorImage = undefined;
        pub var vkCmdDispatch: pfn.vkCmdDispatch = undefined;
        pub var vkCmdDispatchIndirect: pfn.vkCmdDispatchIndirect = undefined;
        pub var vkCmdSetEvent: pfn.vkCmdSetEvent = undefined;
        pub var vkCmdResetEvent: pfn.vkCmdResetEvent = undefined;
        pub var vkCmdWaitEvents: pfn.vkCmdWaitEvents = undefined;
        pub var vkCmdPushConstants: pfn.vkCmdPushConstants = undefined;
        pub var vkCreateGraphicsPipelines: pfn.vkCreateGraphicsPipelines = undefined;
        pub var vkCreateFramebuffer: pfn.vkCreateFramebuffer = undefined;
        pub var vkDestroyFramebuffer: pfn.vkDestroyFramebuffer = undefined;
        pub var vkCreateRenderPass: pfn.vkCreateRenderPass = undefined;
        pub var vkDestroyRenderPass: pfn.vkDestroyRenderPass = undefined;
        pub var vkGetRenderAreaGranularity: pfn.vkGetRenderAreaGranularity = undefined;
        pub var vkCmdSetViewport: pfn.vkCmdSetViewport = undefined;
        pub var vkCmdSetScissor: pfn.vkCmdSetScissor = undefined;
        pub var vkCmdSetLineWidth: pfn.vkCmdSetLineWidth = undefined;
        pub var vkCmdSetDepthBias: pfn.vkCmdSetDepthBias = undefined;
        pub var vkCmdSetBlendConstants: pfn.vkCmdSetBlendConstants = undefined;
        pub var vkCmdSetDepthBounds: pfn.vkCmdSetDepthBounds = undefined;
        pub var vkCmdSetStencilCompareMask: pfn.vkCmdSetStencilCompareMask = undefined;
        pub var vkCmdSetStencilWriteMask: pfn.vkCmdSetStencilWriteMask = undefined;
        pub var vkCmdSetStencilReference: pfn.vkCmdSetStencilReference = undefined;
        pub var vkCmdBindIndexBuffer: pfn.vkCmdBindIndexBuffer = undefined;
        pub var vkCmdBindVertexBuffers: pfn.vkCmdBindVertexBuffers = undefined;
        pub var vkCmdDraw: pfn.vkCmdDraw = undefined;
        pub var vkCmdDrawIndexed: pfn.vkCmdDrawIndexed = undefined;
        pub var vkCmdDrawIndirect: pfn.vkCmdDrawIndirect = undefined;
        pub var vkCmdDrawIndexedIndirect: pfn.vkCmdDrawIndexedIndirect = undefined;
        pub var vkCmdBlitImage: pfn.vkCmdBlitImage = undefined;
        pub var vkCmdClearDepthStencilImage: pfn.vkCmdClearDepthStencilImage = undefined;
        pub var vkCmdClearAttachments: pfn.vkCmdClearAttachments = undefined;
        pub var vkCmdResolveImage: pfn.vkCmdResolveImage = undefined;
        pub var vkCmdBeginRenderPass: pfn.vkCmdBeginRenderPass = undefined;
        pub var vkCmdNextSubpass: pfn.vkCmdNextSubpass = undefined;
        pub var vkCmdEndRenderPass: pfn.vkCmdEndRenderPass = undefined;
        pub var vkBindBufferMemory2: pfn.vkBindBufferMemory2 = undefined;
        pub var vkBindImageMemory2: pfn.vkBindImageMemory2 = undefined;
        pub var vkGetDeviceGroupPeerMemoryFeatures: pfn.vkGetDeviceGroupPeerMemoryFeatures = undefined;
        pub var vkCmdSetDeviceMask: pfn.vkCmdSetDeviceMask = undefined;
        pub var vkGetImageMemoryRequirements2: pfn.vkGetImageMemoryRequirements2 = undefined;
        pub var vkGetBufferMemoryRequirements2: pfn.vkGetBufferMemoryRequirements2 = undefined;
        pub var vkGetImageSparseMemoryRequirements2: pfn.vkGetImageSparseMemoryRequirements2 = undefined;
        pub var vkTrimCommandPool: pfn.vkTrimCommandPool = undefined;
        pub var vkGetDeviceQueue2: pfn.vkGetDeviceQueue2 = undefined;
        pub var vkCmdDispatchBase: pfn.vkCmdDispatchBase = undefined;
        pub var vkCreateDescriptorUpdateTemplate: pfn.vkCreateDescriptorUpdateTemplate = undefined;
        pub var vkDestroyDescriptorUpdateTemplate: pfn.vkDestroyDescriptorUpdateTemplate = undefined;
        pub var vkUpdateDescriptorSetWithTemplate: pfn.vkUpdateDescriptorSetWithTemplate = undefined;
        pub var vkGetDescriptorSetLayoutSupport: pfn.vkGetDescriptorSetLayoutSupport = undefined;
        pub var vkCreateSamplerYcbcrConversion: pfn.vkCreateSamplerYcbcrConversion = undefined;
        pub var vkDestroySamplerYcbcrConversion: pfn.vkDestroySamplerYcbcrConversion = undefined;
        pub var vkResetQueryPool: pfn.vkResetQueryPool = undefined;
        pub var vkGetSemaphoreCounterValue: pfn.vkGetSemaphoreCounterValue = undefined;
        pub var vkWaitSemaphores: pfn.vkWaitSemaphores = undefined;
        pub var vkSignalSemaphore: pfn.vkSignalSemaphore = undefined;
        pub var vkGetBufferDeviceAddress: pfn.vkGetBufferDeviceAddress = undefined;
        pub var vkGetBufferOpaqueCaptureAddress: pfn.vkGetBufferOpaqueCaptureAddress = undefined;
        pub var vkGetDeviceMemoryOpaqueCaptureAddress: pfn.vkGetDeviceMemoryOpaqueCaptureAddress = undefined;
        pub var vkCmdDrawIndirectCount: pfn.vkCmdDrawIndirectCount = undefined;
        pub var vkCmdDrawIndexedIndirectCount: pfn.vkCmdDrawIndexedIndirectCount = undefined;
        pub var vkCreateRenderPass2: pfn.vkCreateRenderPass2 = undefined;
        pub var vkCmdBeginRenderPass2: pfn.vkCmdBeginRenderPass2 = undefined;
        pub var vkCmdNextSubpass2: pfn.vkCmdNextSubpass2 = undefined;
        pub var vkCmdEndRenderPass2: pfn.vkCmdEndRenderPass2 = undefined;
        pub var vkCreatePrivateDataSlot: pfn.vkCreatePrivateDataSlot = undefined;
        pub var vkDestroyPrivateDataSlot: pfn.vkDestroyPrivateDataSlot = undefined;
        pub var vkSetPrivateData: pfn.vkSetPrivateData = undefined;
        pub var vkGetPrivateData: pfn.vkGetPrivateData = undefined;
        pub var vkCmdPipelineBarrier2: pfn.vkCmdPipelineBarrier2 = undefined;
        pub var vkCmdWriteTimestamp2: pfn.vkCmdWriteTimestamp2 = undefined;
        pub var vkQueueSubmit2: pfn.vkQueueSubmit2 = undefined;
        pub var vkCmdCopyBuffer2: pfn.vkCmdCopyBuffer2 = undefined;
        pub var vkCmdCopyImage2: pfn.vkCmdCopyImage2 = undefined;
        pub var vkCmdCopyBufferToImage2: pfn.vkCmdCopyBufferToImage2 = undefined;
        pub var vkCmdCopyImageToBuffer2: pfn.vkCmdCopyImageToBuffer2 = undefined;
        pub var vkGetDeviceBufferMemoryRequirements: pfn.vkGetDeviceBufferMemoryRequirements = undefined;
        pub var vkGetDeviceImageMemoryRequirements: pfn.vkGetDeviceImageMemoryRequirements = undefined;
        pub var vkGetDeviceImageSparseMemoryRequirements: pfn.vkGetDeviceImageSparseMemoryRequirements = undefined;
        pub var vkCmdSetEvent2: pfn.vkCmdSetEvent2 = undefined;
        pub var vkCmdResetEvent2: pfn.vkCmdResetEvent2 = undefined;
        pub var vkCmdWaitEvents2: pfn.vkCmdWaitEvents2 = undefined;
        pub var vkCmdBlitImage2: pfn.vkCmdBlitImage2 = undefined;
        pub var vkCmdResolveImage2: pfn.vkCmdResolveImage2 = undefined;
        pub var vkCmdBeginRendering: pfn.vkCmdBeginRendering = undefined;
        pub var vkCmdEndRendering: pfn.vkCmdEndRendering = undefined;
        pub var vkCmdSetCullMode: pfn.vkCmdSetCullMode = undefined;
        pub var vkCmdSetFrontFace: pfn.vkCmdSetFrontFace = undefined;
        pub var vkCmdSetPrimitiveTopology: pfn.vkCmdSetPrimitiveTopology = undefined;
        pub var vkCmdSetViewportWithCount: pfn.vkCmdSetViewportWithCount = undefined;
        pub var vkCmdSetScissorWithCount: pfn.vkCmdSetScissorWithCount = undefined;
        pub var vkCmdBindVertexBuffers2: pfn.vkCmdBindVertexBuffers2 = undefined;
        pub var vkCmdSetDepthTestEnable: pfn.vkCmdSetDepthTestEnable = undefined;
        pub var vkCmdSetDepthWriteEnable: pfn.vkCmdSetDepthWriteEnable = undefined;
        pub var vkCmdSetDepthCompareOp: pfn.vkCmdSetDepthCompareOp = undefined;
        pub var vkCmdSetDepthBoundsTestEnable: pfn.vkCmdSetDepthBoundsTestEnable = undefined;
        pub var vkCmdSetStencilTestEnable: pfn.vkCmdSetStencilTestEnable = undefined;
        pub var vkCmdSetStencilOp: pfn.vkCmdSetStencilOp = undefined;
        pub var vkCmdSetRasterizerDiscardEnable: pfn.vkCmdSetRasterizerDiscardEnable = undefined;
        pub var vkCmdSetDepthBiasEnable: pfn.vkCmdSetDepthBiasEnable = undefined;
        pub var vkCmdSetPrimitiveRestartEnable: pfn.vkCmdSetPrimitiveRestartEnable = undefined;
        pub var vkCreateSwapchainKHR: pfn.vkCreateSwapchainKHR = undefined;
        pub var vkDestroySwapchainKHR: pfn.vkDestroySwapchainKHR = undefined;
        pub var vkGetSwapchainImagesKHR: pfn.vkGetSwapchainImagesKHR = undefined;
        pub var vkAcquireNextImageKHR: pfn.vkAcquireNextImageKHR = undefined;
        pub var vkQueuePresentKHR: pfn.vkQueuePresentKHR = undefined;
        pub var vkGetDeviceGroupPresentCapabilitiesKHR: pfn.vkGetDeviceGroupPresentCapabilitiesKHR = undefined;
        pub var vkGetDeviceGroupSurfacePresentModesKHR: pfn.vkGetDeviceGroupSurfacePresentModesKHR = undefined;
        pub var vkAcquireNextImage2KHR: pfn.vkAcquireNextImage2KHR = undefined;
        pub var vkSetDebugUtilsObjectNameEXT: pfn.vkSetDebugUtilsObjectNameEXT = undefined;
        pub var vkSetDebugUtilsObjectTagEXT: pfn.vkSetDebugUtilsObjectTagEXT = undefined;
        pub var vkQueueBeginDebugUtilsLabelEXT: pfn.vkQueueBeginDebugUtilsLabelEXT = undefined;
        pub var vkQueueEndDebugUtilsLabelEXT: pfn.vkQueueEndDebugUtilsLabelEXT = undefined;
        pub var vkQueueInsertDebugUtilsLabelEXT: pfn.vkQueueInsertDebugUtilsLabelEXT = undefined;
        pub var vkCmdBeginDebugUtilsLabelEXT: pfn.vkCmdBeginDebugUtilsLabelEXT = undefined;
        pub var vkCmdEndDebugUtilsLabelEXT: pfn.vkCmdEndDebugUtilsLabelEXT = undefined;
        pub var vkCmdInsertDebugUtilsLabelEXT: pfn.vkCmdInsertDebugUtilsLabelEXT = undefined;
    };
};
pub const pfn = struct {
    pub const AllocationFunction = ?*const fn (pUserData: ?*anyopaque, size: u64, alignment: u64, allocationScope: SystemAllocationScope) callconv(.c) ?*anyopaque;
    pub const FreeFunction = ?*const fn (pUserData: ?*anyopaque, pMemory: ?*anyopaque) callconv(.c) void;
    pub const InternalAllocationNotification = ?*const fn (pUserData: ?*anyopaque, size: u64, allocationType: InternalAllocationType, allocationScope: SystemAllocationScope) callconv(.c) void;
    pub const InternalFreeNotification = ?*const fn (pUserData: ?*anyopaque, size: u64, allocationType: InternalAllocationType, allocationScope: SystemAllocationScope) callconv(.c) void;
    pub const ReallocationFunction = ?*const fn (pUserData: ?*anyopaque, pOriginal: ?*anyopaque, size: u64, alignment: u64, allocationScope: SystemAllocationScope) callconv(.c) ?*anyopaque;
    pub const VoidFunction = ?*const fn () callconv(.c) void;
    pub const DebugUtilsMessengerCallbackEXT = ?*const fn (messageSeverity: DebugUtilsMessageSeverityFlagsEXT, messageTypes: DebugUtilsMessageTypeFlagsEXT, pCallbackData: *DebugUtilsMessengerCallbackDataEXT, pUserData: ?*anyopaque) callconv(.c) Bool;
    pub const GetInstanceProcAddrLUNARG = ?*const fn (instance: Instance, pName: [*:0]const u8) callconv(.c) pfn.VoidFunction;
    pub const vkCreateInstance = *const fn (pCreateInfo: *const InstanceCreateInfo, pAllocator: ?*const AllocationCallbacks, pInstance: *Instance) callconv(.c) Result;
    pub const vkDestroyInstance = *const fn (instance: ?Instance, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkEnumeratePhysicalDevices = *const fn (instance: Instance, pPhysicalDeviceCount: ?*u32, pPhysicalDevices: ?[*]PhysicalDevice) callconv(.c) Result;
    pub const vkGetPhysicalDeviceFeatures = *const fn (physicalDevice: PhysicalDevice, pFeatures: *PhysicalDeviceFeatures) callconv(.c) void;
    pub const vkGetPhysicalDeviceFormatProperties = *const fn (physicalDevice: PhysicalDevice, format: Format, pFormatProperties: *FormatProperties) callconv(.c) void;
    pub const vkGetPhysicalDeviceImageFormatProperties = *const fn (physicalDevice: PhysicalDevice, format: Format, Type: ImageType, tiling: ImageTiling, usage: ImageUsageFlags, flags: ImageCreateFlags, pImageFormatProperties: *ImageFormatProperties) callconv(.c) Result;
    pub const vkGetPhysicalDeviceProperties = *const fn (physicalDevice: PhysicalDevice, pProperties: *PhysicalDeviceProperties) callconv(.c) void;
    pub const vkGetPhysicalDeviceQueueFamilyProperties = *const fn (physicalDevice: PhysicalDevice, pQueueFamilyPropertyCount: ?*u32, pQueueFamilyProperties: ?[*]QueueFamilyProperties) callconv(.c) void;
    pub const vkGetPhysicalDeviceMemoryProperties = *const fn (physicalDevice: PhysicalDevice, pMemoryProperties: *PhysicalDeviceMemoryProperties) callconv(.c) void;
    pub const vkGetInstanceProcAddr = *const fn (instance: ?Instance, pName: [*:0]const u8) callconv(.c) pfn.VoidFunction;
    pub const vkGetDeviceProcAddr = *const fn (device: Device, pName: [*:0]const u8) callconv(.c) pfn.VoidFunction;
    pub const vkCreateDevice = *const fn (physicalDevice: PhysicalDevice, pCreateInfo: *const DeviceCreateInfo, pAllocator: ?*const AllocationCallbacks, pDevice: *Device) callconv(.c) Result;
    pub const vkDestroyDevice = *const fn (device: ?Device, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkEnumerateInstanceExtensionProperties = *const fn (pLayerName: ?[*:0]const u8, pPropertyCount: ?*u32, pProperties: ?[*]ExtensionProperties) callconv(.c) Result;
    pub const vkEnumerateDeviceExtensionProperties = *const fn (physicalDevice: PhysicalDevice, pLayerName: ?[*:0]const u8, pPropertyCount: ?*u32, pProperties: ?[*]ExtensionProperties) callconv(.c) Result;
    pub const vkEnumerateInstanceLayerProperties = *const fn (pPropertyCount: ?*u32, pProperties: ?[*]LayerProperties) callconv(.c) Result;
    pub const vkEnumerateDeviceLayerProperties = *const fn (physicalDevice: PhysicalDevice, pPropertyCount: ?*u32, pProperties: ?[*]LayerProperties) callconv(.c) Result;
    pub const vkGetDeviceQueue = *const fn (device: Device, queueFamilyIndex: u32, queueIndex: u32, pQueue: *Queue) callconv(.c) void;
    pub const vkQueueSubmit = *const fn (queue: Queue, submitCount: u32, pSubmits: [*]const SubmitInfo, fence: ?Fence) callconv(.c) Result;
    pub const vkQueueWaitIdle = *const fn (queue: Queue) callconv(.c) Result;
    pub const vkDeviceWaitIdle = *const fn (device: Device) callconv(.c) Result;
    pub const vkAllocateMemory = *const fn (device: Device, pAllocateInfo: *const MemoryAllocateInfo, pAllocator: ?*const AllocationCallbacks, pMemory: *DeviceMemory) callconv(.c) Result;
    pub const vkFreeMemory = *const fn (device: Device, memory: ?DeviceMemory, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkMapMemory = *const fn (device: Device, memory: DeviceMemory, offset: DeviceSize, size: DeviceSize, flags: MemoryMapFlags, ppData: [*]const ?*anyopaque) callconv(.c) Result;
    pub const vkUnmapMemory = *const fn (device: Device, memory: DeviceMemory) callconv(.c) void;
    pub const vkFlushMappedMemoryRanges = *const fn (device: Device, memoryRangeCount: u32, pMemoryRanges: [*]const MappedMemoryRange) callconv(.c) Result;
    pub const vkInvalidateMappedMemoryRanges = *const fn (device: Device, memoryRangeCount: u32, pMemoryRanges: [*]const MappedMemoryRange) callconv(.c) Result;
    pub const vkGetDeviceMemoryCommitment = *const fn (device: Device, memory: DeviceMemory, pCommittedMemoryInBytes: *DeviceSize) callconv(.c) void;
    pub const vkBindBufferMemory = *const fn (device: Device, buffer: Buffer, memory: DeviceMemory, memoryOffset: DeviceSize) callconv(.c) Result;
    pub const vkBindImageMemory = *const fn (device: Device, image: Image, memory: DeviceMemory, memoryOffset: DeviceSize) callconv(.c) Result;
    pub const vkGetBufferMemoryRequirements = *const fn (device: Device, buffer: Buffer, pMemoryRequirements: *MemoryRequirements) callconv(.c) void;
    pub const vkGetImageMemoryRequirements = *const fn (device: Device, image: Image, pMemoryRequirements: *MemoryRequirements) callconv(.c) void;
    pub const vkGetImageSparseMemoryRequirements = *const fn (device: Device, image: Image, pSparseMemoryRequirementCount: ?*u32, pSparseMemoryRequirements: ?[*]SparseImageMemoryRequirements) callconv(.c) void;
    pub const vkGetPhysicalDeviceSparseImageFormatProperties = *const fn (physicalDevice: PhysicalDevice, format: Format, Type: ImageType, samples: SampleCountFlags, usage: ImageUsageFlags, tiling: ImageTiling, pPropertyCount: ?*u32, pProperties: ?[*]SparseImageFormatProperties) callconv(.c) void;
    pub const vkQueueBindSparse = *const fn (queue: Queue, bindInfoCount: u32, pBindInfo: [*]const BindSparseInfo, fence: ?Fence) callconv(.c) Result;
    pub const vkCreateFence = *const fn (device: Device, pCreateInfo: *const FenceCreateInfo, pAllocator: ?*const AllocationCallbacks, pFence: *Fence) callconv(.c) Result;
    pub const vkDestroyFence = *const fn (device: Device, fence: ?Fence, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkResetFences = *const fn (device: Device, fenceCount: u32, pFences: [*]const Fence) callconv(.c) Result;
    pub const vkGetFenceStatus = *const fn (device: Device, fence: Fence) callconv(.c) Result;
    pub const vkWaitForFences = *const fn (device: Device, fenceCount: u32, pFences: [*]const Fence, waitAll: Bool, timeout: u64) callconv(.c) Result;
    pub const vkCreateSemaphore = *const fn (device: Device, pCreateInfo: *const SemaphoreCreateInfo, pAllocator: ?*const AllocationCallbacks, pSemaphore: *Semaphore) callconv(.c) Result;
    pub const vkDestroySemaphore = *const fn (device: Device, semaphore: ?Semaphore, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkCreateQueryPool = *const fn (device: Device, pCreateInfo: *const QueryPoolCreateInfo, pAllocator: ?*const AllocationCallbacks, pQueryPool: *QueryPool) callconv(.c) Result;
    pub const vkDestroyQueryPool = *const fn (device: Device, queryPool: ?QueryPool, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkGetQueryPoolResults = *const fn (device: Device, queryPool: QueryPool, firstQuery: u32, queryCount: u32, dataSize: u64, pData: [*]u8, stride: DeviceSize, flags: QueryResultFlags) callconv(.c) Result;
    pub const vkCreateBuffer = *const fn (device: Device, pCreateInfo: *const BufferCreateInfo, pAllocator: ?*const AllocationCallbacks, pBuffer: *Buffer) callconv(.c) Result;
    pub const vkDestroyBuffer = *const fn (device: Device, buffer: ?Buffer, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkCreateImage = *const fn (device: Device, pCreateInfo: *const ImageCreateInfo, pAllocator: ?*const AllocationCallbacks, pImage: *Image) callconv(.c) Result;
    pub const vkDestroyImage = *const fn (device: Device, image: ?Image, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkGetImageSubresourceLayout = *const fn (device: Device, image: Image, pSubresource: *const ImageSubresource, pLayout: *SubresourceLayout) callconv(.c) void;
    pub const vkCreateImageView = *const fn (device: Device, pCreateInfo: *const ImageViewCreateInfo, pAllocator: ?*const AllocationCallbacks, pView: *ImageView) callconv(.c) Result;
    pub const vkDestroyImageView = *const fn (device: Device, imageView: ?ImageView, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkCreateCommandPool = *const fn (device: Device, pCreateInfo: *const CommandPoolCreateInfo, pAllocator: ?*const AllocationCallbacks, pCommandPool: *CommandPool) callconv(.c) Result;
    pub const vkDestroyCommandPool = *const fn (device: Device, commandPool: ?CommandPool, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkResetCommandPool = *const fn (device: Device, commandPool: CommandPool, flags: CommandPoolResetFlags) callconv(.c) Result;
    pub const vkAllocateCommandBuffers = *const fn (device: Device, pAllocateInfo: *const CommandBufferAllocateInfo, pCommandBuffers: [*]CommandBuffer) callconv(.c) Result;
    pub const vkFreeCommandBuffers = *const fn (device: Device, commandPool: CommandPool, commandBufferCount: u32, pCommandBuffers: [*]const CommandBuffer) callconv(.c) void;
    pub const vkBeginCommandBuffer = *const fn (commandBuffer: CommandBuffer, pBeginInfo: *const CommandBufferBeginInfo) callconv(.c) Result;
    pub const vkEndCommandBuffer = *const fn (commandBuffer: CommandBuffer) callconv(.c) Result;
    pub const vkResetCommandBuffer = *const fn (commandBuffer: CommandBuffer, flags: CommandBufferResetFlags) callconv(.c) Result;
    pub const vkCmdCopyBuffer = *const fn (commandBuffer: CommandBuffer, srcBuffer: Buffer, dstBuffer: Buffer, regionCount: u32, pRegions: [*]const BufferCopy) callconv(.c) void;
    pub const vkCmdCopyImage = *const fn (commandBuffer: CommandBuffer, srcImage: Image, srcImageLayout: ImageLayout, dstImage: Image, dstImageLayout: ImageLayout, regionCount: u32, pRegions: [*]const ImageCopy) callconv(.c) void;
    pub const vkCmdCopyBufferToImage = *const fn (commandBuffer: CommandBuffer, srcBuffer: Buffer, dstImage: Image, dstImageLayout: ImageLayout, regionCount: u32, pRegions: [*]const BufferImageCopy) callconv(.c) void;
    pub const vkCmdCopyImageToBuffer = *const fn (commandBuffer: CommandBuffer, srcImage: Image, srcImageLayout: ImageLayout, dstBuffer: Buffer, regionCount: u32, pRegions: [*]const BufferImageCopy) callconv(.c) void;
    pub const vkCmdUpdateBuffer = *const fn (commandBuffer: CommandBuffer, dstBuffer: Buffer, dstOffset: DeviceSize, dataSize: DeviceSize, pData: [*]const u8) callconv(.c) void;
    pub const vkCmdFillBuffer = *const fn (commandBuffer: CommandBuffer, dstBuffer: Buffer, dstOffset: DeviceSize, size: DeviceSize, data: u32) callconv(.c) void;
    pub const vkCmdPipelineBarrier = *const fn (commandBuffer: CommandBuffer, srcStageMask: PipelineStageFlags, dstStageMask: PipelineStageFlags, dependencyFlags: DependencyFlags, memoryBarrierCount: u32, pMemoryBarriers: [*]const MemoryBarrier, bufferMemoryBarrierCount: u32, pBufferMemoryBarriers: [*]const BufferMemoryBarrier, imageMemoryBarrierCount: u32, pImageMemoryBarriers: [*]const ImageMemoryBarrier) callconv(.c) void;
    pub const vkCmdBeginQuery = *const fn (commandBuffer: CommandBuffer, queryPool: QueryPool, query: u32, flags: QueryControlFlags) callconv(.c) void;
    pub const vkCmdEndQuery = *const fn (commandBuffer: CommandBuffer, queryPool: QueryPool, query: u32) callconv(.c) void;
    pub const vkCmdResetQueryPool = *const fn (commandBuffer: CommandBuffer, queryPool: QueryPool, firstQuery: u32, queryCount: u32) callconv(.c) void;
    pub const vkCmdWriteTimestamp = *const fn (commandBuffer: CommandBuffer, pipelineStage: PipelineStageFlags, queryPool: QueryPool, query: u32) callconv(.c) void;
    pub const vkCmdCopyQueryPoolResults = *const fn (commandBuffer: CommandBuffer, queryPool: QueryPool, firstQuery: u32, queryCount: u32, dstBuffer: Buffer, dstOffset: DeviceSize, stride: DeviceSize, flags: QueryResultFlags) callconv(.c) void;
    pub const vkCmdExecuteCommands = *const fn (commandBuffer: CommandBuffer, commandBufferCount: u32, pCommandBuffers: [*]const CommandBuffer) callconv(.c) void;
    pub const vkCreateEvent = *const fn (device: Device, pCreateInfo: *const EventCreateInfo, pAllocator: ?*const AllocationCallbacks, pEvent: *Event) callconv(.c) Result;
    pub const vkDestroyEvent = *const fn (device: Device, event: ?Event, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkGetEventStatus = *const fn (device: Device, event: Event) callconv(.c) Result;
    pub const vkSetEvent = *const fn (device: Device, event: Event) callconv(.c) Result;
    pub const vkResetEvent = *const fn (device: Device, event: Event) callconv(.c) Result;
    pub const vkCreateBufferView = *const fn (device: Device, pCreateInfo: *const BufferViewCreateInfo, pAllocator: ?*const AllocationCallbacks, pView: *BufferView) callconv(.c) Result;
    pub const vkDestroyBufferView = *const fn (device: Device, bufferView: ?BufferView, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkCreateShaderModule = *const fn (device: Device, pCreateInfo: *const ShaderModuleCreateInfo, pAllocator: ?*const AllocationCallbacks, pShaderModule: *ShaderModule) callconv(.c) Result;
    pub const vkDestroyShaderModule = *const fn (device: Device, shaderModule: ?ShaderModule, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkCreatePipelineCache = *const fn (device: Device, pCreateInfo: *const PipelineCacheCreateInfo, pAllocator: ?*const AllocationCallbacks, pPipelineCache: *PipelineCache) callconv(.c) Result;
    pub const vkDestroyPipelineCache = *const fn (device: Device, pipelineCache: ?PipelineCache, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkGetPipelineCacheData = *const fn (device: Device, pipelineCache: PipelineCache, pDataSize: ?*u64, pData: ?[*]u8) callconv(.c) Result;
    pub const vkMergePipelineCaches = *const fn (device: Device, dstCache: PipelineCache, srcCacheCount: u32, pSrcCaches: [*]const PipelineCache) callconv(.c) Result;
    pub const vkCreateComputePipelines = *const fn (device: Device, pipelineCache: ?PipelineCache, createInfoCount: u32, pCreateInfos: [*]const ComputePipelineCreateInfo, pAllocator: ?*const AllocationCallbacks, pPipelines: [*]Pipeline) callconv(.c) Result;
    pub const vkDestroyPipeline = *const fn (device: Device, pipeline: ?Pipeline, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkCreatePipelineLayout = *const fn (device: Device, pCreateInfo: *const PipelineLayoutCreateInfo, pAllocator: ?*const AllocationCallbacks, pPipelineLayout: *PipelineLayout) callconv(.c) Result;
    pub const vkDestroyPipelineLayout = *const fn (device: Device, pipelineLayout: ?PipelineLayout, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkCreateSampler = *const fn (device: Device, pCreateInfo: *const SamplerCreateInfo, pAllocator: ?*const AllocationCallbacks, pSampler: *Sampler) callconv(.c) Result;
    pub const vkDestroySampler = *const fn (device: Device, sampler: ?Sampler, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkCreateDescriptorSetLayout = *const fn (device: Device, pCreateInfo: *const DescriptorSetLayoutCreateInfo, pAllocator: ?*const AllocationCallbacks, pSetLayout: *DescriptorSetLayout) callconv(.c) Result;
    pub const vkDestroyDescriptorSetLayout = *const fn (device: Device, descriptorSetLayout: ?DescriptorSetLayout, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkCreateDescriptorPool = *const fn (device: Device, pCreateInfo: *const DescriptorPoolCreateInfo, pAllocator: ?*const AllocationCallbacks, pDescriptorPool: *DescriptorPool) callconv(.c) Result;
    pub const vkDestroyDescriptorPool = *const fn (device: Device, descriptorPool: ?DescriptorPool, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkResetDescriptorPool = *const fn (device: Device, descriptorPool: DescriptorPool, flags: DescriptorPoolResetFlags) callconv(.c) Result;
    pub const vkAllocateDescriptorSets = *const fn (device: Device, pAllocateInfo: *const DescriptorSetAllocateInfo, pDescriptorSets: [*]DescriptorSet) callconv(.c) Result;
    pub const vkFreeDescriptorSets = *const fn (device: Device, descriptorPool: DescriptorPool, descriptorSetCount: u32, pDescriptorSets: [*]const DescriptorSet) callconv(.c) Result;
    pub const vkUpdateDescriptorSets = *const fn (device: Device, descriptorWriteCount: u32, pDescriptorWrites: [*]const WriteDescriptorSet, descriptorCopyCount: u32, pDescriptorCopies: [*]const CopyDescriptorSet) callconv(.c) void;
    pub const vkCmdBindPipeline = *const fn (commandBuffer: CommandBuffer, pipelineBindPoint: PipelineBindPoint, pipeline: Pipeline) callconv(.c) void;
    pub const vkCmdBindDescriptorSets = *const fn (commandBuffer: CommandBuffer, pipelineBindPoint: PipelineBindPoint, layout: PipelineLayout, firstSet: u32, descriptorSetCount: u32, pDescriptorSets: ?[*]const DescriptorSet, dynamicOffsetCount: u32, pDynamicOffsets: [*]const u32) callconv(.c) void;
    pub const vkCmdClearColorImage = *const fn (commandBuffer: CommandBuffer, image: Image, imageLayout: ImageLayout, pColor: *const ClearColorValue, rangeCount: u32, pRanges: [*]const ImageSubresourceRange) callconv(.c) void;
    pub const vkCmdDispatch = *const fn (commandBuffer: CommandBuffer, groupCountX: u32, groupCountY: u32, groupCountZ: u32) callconv(.c) void;
    pub const vkCmdDispatchIndirect = *const fn (commandBuffer: CommandBuffer, buffer: Buffer, offset: DeviceSize) callconv(.c) void;
    pub const vkCmdSetEvent = *const fn (commandBuffer: CommandBuffer, event: Event, stageMask: PipelineStageFlags) callconv(.c) void;
    pub const vkCmdResetEvent = *const fn (commandBuffer: CommandBuffer, event: Event, stageMask: PipelineStageFlags) callconv(.c) void;
    pub const vkCmdWaitEvents = *const fn (commandBuffer: CommandBuffer, eventCount: u32, pEvents: [*]const Event, srcStageMask: PipelineStageFlags, dstStageMask: PipelineStageFlags, memoryBarrierCount: u32, pMemoryBarriers: [*]const MemoryBarrier, bufferMemoryBarrierCount: u32, pBufferMemoryBarriers: [*]const BufferMemoryBarrier, imageMemoryBarrierCount: u32, pImageMemoryBarriers: [*]const ImageMemoryBarrier) callconv(.c) void;
    pub const vkCmdPushConstants = *const fn (commandBuffer: CommandBuffer, layout: PipelineLayout, stageFlags: ShaderStageFlags, offset: u32, size: u32, pValues: [*]const u8) callconv(.c) void;
    pub const vkCreateGraphicsPipelines = *const fn (device: Device, pipelineCache: ?PipelineCache, createInfoCount: u32, pCreateInfos: [*]const GraphicsPipelineCreateInfo, pAllocator: ?*const AllocationCallbacks, pPipelines: [*]Pipeline) callconv(.c) Result;
    pub const vkCreateFramebuffer = *const fn (device: Device, pCreateInfo: *const FramebufferCreateInfo, pAllocator: ?*const AllocationCallbacks, pFramebuffer: *Framebuffer) callconv(.c) Result;
    pub const vkDestroyFramebuffer = *const fn (device: Device, framebuffer: ?Framebuffer, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkCreateRenderPass = *const fn (device: Device, pCreateInfo: *const RenderPassCreateInfo, pAllocator: ?*const AllocationCallbacks, pRenderPass: *RenderPass) callconv(.c) Result;
    pub const vkDestroyRenderPass = *const fn (device: Device, renderPass: ?RenderPass, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkGetRenderAreaGranularity = *const fn (device: Device, renderPass: RenderPass, pGranularity: *Extent2D) callconv(.c) void;
    pub const vkCmdSetViewport = *const fn (commandBuffer: CommandBuffer, firstViewport: u32, viewportCount: u32, pViewports: [*]const Viewport) callconv(.c) void;
    pub const vkCmdSetScissor = *const fn (commandBuffer: CommandBuffer, firstScissor: u32, scissorCount: u32, pScissors: [*]const Rect2D) callconv(.c) void;
    pub const vkCmdSetLineWidth = *const fn (commandBuffer: CommandBuffer, lineWidth: f32) callconv(.c) void;
    pub const vkCmdSetDepthBias = *const fn (commandBuffer: CommandBuffer, depthBiasConstantFactor: f32, depthBiasClamp: f32, depthBiasSlopeFactor: f32) callconv(.c) void;
    pub const vkCmdSetBlendConstants = *const fn (commandBuffer: CommandBuffer, blendConstants: [4]f32) callconv(.c) void;
    pub const vkCmdSetDepthBounds = *const fn (commandBuffer: CommandBuffer, minDepthBounds: f32, maxDepthBounds: f32) callconv(.c) void;
    pub const vkCmdSetStencilCompareMask = *const fn (commandBuffer: CommandBuffer, faceMask: StencilFaceFlags, compareMask: u32) callconv(.c) void;
    pub const vkCmdSetStencilWriteMask = *const fn (commandBuffer: CommandBuffer, faceMask: StencilFaceFlags, writeMask: u32) callconv(.c) void;
    pub const vkCmdSetStencilReference = *const fn (commandBuffer: CommandBuffer, faceMask: StencilFaceFlags, reference: u32) callconv(.c) void;
    pub const vkCmdBindIndexBuffer = *const fn (commandBuffer: CommandBuffer, buffer: ?Buffer, offset: DeviceSize, indexType: IndexType) callconv(.c) void;
    pub const vkCmdBindVertexBuffers = *const fn (commandBuffer: CommandBuffer, firstBinding: u32, bindingCount: u32, pBuffers: ?[*]const Buffer, pOffsets: [*]const DeviceSize) callconv(.c) void;
    pub const vkCmdDraw = *const fn (commandBuffer: CommandBuffer, vertexCount: u32, instanceCount: u32, firstVertex: u32, firstInstance: u32) callconv(.c) void;
    pub const vkCmdDrawIndexed = *const fn (commandBuffer: CommandBuffer, indexCount: u32, instanceCount: u32, firstIndex: u32, vertexOffset: i32, firstInstance: u32) callconv(.c) void;
    pub const vkCmdDrawIndirect = *const fn (commandBuffer: CommandBuffer, buffer: Buffer, offset: DeviceSize, drawCount: u32, stride: u32) callconv(.c) void;
    pub const vkCmdDrawIndexedIndirect = *const fn (commandBuffer: CommandBuffer, buffer: Buffer, offset: DeviceSize, drawCount: u32, stride: u32) callconv(.c) void;
    pub const vkCmdBlitImage = *const fn (commandBuffer: CommandBuffer, srcImage: Image, srcImageLayout: ImageLayout, dstImage: Image, dstImageLayout: ImageLayout, regionCount: u32, pRegions: [*]const ImageBlit, filter: Filter) callconv(.c) void;
    pub const vkCmdClearDepthStencilImage = *const fn (commandBuffer: CommandBuffer, image: Image, imageLayout: ImageLayout, pDepthStencil: *const ClearDepthStencilValue, rangeCount: u32, pRanges: [*]const ImageSubresourceRange) callconv(.c) void;
    pub const vkCmdClearAttachments = *const fn (commandBuffer: CommandBuffer, attachmentCount: u32, pAttachments: [*]const ClearAttachment, rectCount: u32, pRects: [*]const ClearRect) callconv(.c) void;
    pub const vkCmdResolveImage = *const fn (commandBuffer: CommandBuffer, srcImage: Image, srcImageLayout: ImageLayout, dstImage: Image, dstImageLayout: ImageLayout, regionCount: u32, pRegions: [*]const ImageResolve) callconv(.c) void;
    pub const vkCmdBeginRenderPass = *const fn (commandBuffer: CommandBuffer, pRenderPassBegin: *const RenderPassBeginInfo, contents: SubpassContents) callconv(.c) void;
    pub const vkCmdNextSubpass = *const fn (commandBuffer: CommandBuffer, contents: SubpassContents) callconv(.c) void;
    pub const vkCmdEndRenderPass = *const fn (commandBuffer: CommandBuffer) callconv(.c) void;
    pub const vkEnumerateInstanceVersion = *const fn (pApiVersion: *u32) callconv(.c) Result;
    pub const vkBindBufferMemory2 = *const fn (device: Device, bindInfoCount: u32, pBindInfos: [*]const BindBufferMemoryInfo) callconv(.c) Result;
    pub const vkBindImageMemory2 = *const fn (device: Device, bindInfoCount: u32, pBindInfos: [*]const BindImageMemoryInfo) callconv(.c) Result;
    pub const vkGetDeviceGroupPeerMemoryFeatures = *const fn (device: Device, heapIndex: u32, localDeviceIndex: u32, remoteDeviceIndex: u32, pPeerMemoryFeatures: *PeerMemoryFeatureFlags) callconv(.c) void;
    pub const vkCmdSetDeviceMask = *const fn (commandBuffer: CommandBuffer, deviceMask: u32) callconv(.c) void;
    pub const vkEnumeratePhysicalDeviceGroups = *const fn (instance: Instance, pPhysicalDeviceGroupCount: ?*u32, pPhysicalDeviceGroupProperties: ?[*]PhysicalDeviceGroupProperties) callconv(.c) Result;
    pub const vkGetImageMemoryRequirements2 = *const fn (device: Device, pInfo: *const ImageMemoryRequirementsInfo2, pMemoryRequirements: *MemoryRequirements2) callconv(.c) void;
    pub const vkGetBufferMemoryRequirements2 = *const fn (device: Device, pInfo: *const BufferMemoryRequirementsInfo2, pMemoryRequirements: *MemoryRequirements2) callconv(.c) void;
    pub const vkGetImageSparseMemoryRequirements2 = *const fn (device: Device, pInfo: *const ImageSparseMemoryRequirementsInfo2, pSparseMemoryRequirementCount: ?*u32, pSparseMemoryRequirements: ?[*]SparseImageMemoryRequirements2) callconv(.c) void;
    pub const vkGetPhysicalDeviceFeatures2 = *const fn (physicalDevice: PhysicalDevice, pFeatures: *PhysicalDeviceFeatures2) callconv(.c) void;
    pub const vkGetPhysicalDeviceProperties2 = *const fn (physicalDevice: PhysicalDevice, pProperties: *PhysicalDeviceProperties2) callconv(.c) void;
    pub const vkGetPhysicalDeviceFormatProperties2 = *const fn (physicalDevice: PhysicalDevice, format: Format, pFormatProperties: *FormatProperties2) callconv(.c) void;
    pub const vkGetPhysicalDeviceImageFormatProperties2 = *const fn (physicalDevice: PhysicalDevice, pImageFormatInfo: *const PhysicalDeviceImageFormatInfo2, pImageFormatProperties: *ImageFormatProperties2) callconv(.c) Result;
    pub const vkGetPhysicalDeviceQueueFamilyProperties2 = *const fn (physicalDevice: PhysicalDevice, pQueueFamilyPropertyCount: ?*u32, pQueueFamilyProperties: ?[*]QueueFamilyProperties2) callconv(.c) void;
    pub const vkGetPhysicalDeviceMemoryProperties2 = *const fn (physicalDevice: PhysicalDevice, pMemoryProperties: *PhysicalDeviceMemoryProperties2) callconv(.c) void;
    pub const vkGetPhysicalDeviceSparseImageFormatProperties2 = *const fn (physicalDevice: PhysicalDevice, pFormatInfo: *const PhysicalDeviceSparseImageFormatInfo2, pPropertyCount: ?*u32, pProperties: ?[*]SparseImageFormatProperties2) callconv(.c) void;
    pub const vkTrimCommandPool = *const fn (device: Device, commandPool: CommandPool, flags: CommandPoolTrimFlags) callconv(.c) void;
    pub const vkGetDeviceQueue2 = *const fn (device: Device, pQueueInfo: *const DeviceQueueInfo2, pQueue: *Queue) callconv(.c) void;
    pub const vkGetPhysicalDeviceExternalBufferProperties = *const fn (physicalDevice: PhysicalDevice, pExternalBufferInfo: *const PhysicalDeviceExternalBufferInfo, pExternalBufferProperties: *ExternalBufferProperties) callconv(.c) void;
    pub const vkGetPhysicalDeviceExternalFenceProperties = *const fn (physicalDevice: PhysicalDevice, pExternalFenceInfo: *const PhysicalDeviceExternalFenceInfo, pExternalFenceProperties: *ExternalFenceProperties) callconv(.c) void;
    pub const vkGetPhysicalDeviceExternalSemaphoreProperties = *const fn (physicalDevice: PhysicalDevice, pExternalSemaphoreInfo: *const PhysicalDeviceExternalSemaphoreInfo, pExternalSemaphoreProperties: *ExternalSemaphoreProperties) callconv(.c) void;
    pub const vkCmdDispatchBase = *const fn (commandBuffer: CommandBuffer, baseGroupX: u32, baseGroupY: u32, baseGroupZ: u32, groupCountX: u32, groupCountY: u32, groupCountZ: u32) callconv(.c) void;
    pub const vkCreateDescriptorUpdateTemplate = *const fn (device: Device, pCreateInfo: *const DescriptorUpdateTemplateCreateInfo, pAllocator: ?*const AllocationCallbacks, pDescriptorUpdateTemplate: *DescriptorUpdateTemplate) callconv(.c) Result;
    pub const vkDestroyDescriptorUpdateTemplate = *const fn (device: Device, descriptorUpdateTemplate: ?DescriptorUpdateTemplate, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkUpdateDescriptorSetWithTemplate = *const fn (device: Device, descriptorSet: DescriptorSet, descriptorUpdateTemplate: DescriptorUpdateTemplate, pData: *const anyopaque) callconv(.c) void;
    pub const vkGetDescriptorSetLayoutSupport = *const fn (device: Device, pCreateInfo: *const DescriptorSetLayoutCreateInfo, pSupport: *DescriptorSetLayoutSupport) callconv(.c) void;
    pub const vkCreateSamplerYcbcrConversion = *const fn (device: Device, pCreateInfo: *const SamplerYcbcrConversionCreateInfo, pAllocator: ?*const AllocationCallbacks, pYcbcrConversion: *SamplerYcbcrConversion) callconv(.c) Result;
    pub const vkDestroySamplerYcbcrConversion = *const fn (device: Device, ycbcrConversion: ?SamplerYcbcrConversion, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkResetQueryPool = *const fn (device: Device, queryPool: QueryPool, firstQuery: u32, queryCount: u32) callconv(.c) void;
    pub const vkGetSemaphoreCounterValue = *const fn (device: Device, semaphore: Semaphore, pValue: *u64) callconv(.c) Result;
    pub const vkWaitSemaphores = *const fn (device: Device, pWaitInfo: *const SemaphoreWaitInfo, timeout: u64) callconv(.c) Result;
    pub const vkSignalSemaphore = *const fn (device: Device, pSignalInfo: *const SemaphoreSignalInfo) callconv(.c) Result;
    pub const vkGetBufferDeviceAddress = *const fn (device: Device, pInfo: *const BufferDeviceAddressInfo) callconv(.c) DeviceAddress;
    pub const vkGetBufferOpaqueCaptureAddress = *const fn (device: Device, pInfo: *const BufferDeviceAddressInfo) callconv(.c) u64;
    pub const vkGetDeviceMemoryOpaqueCaptureAddress = *const fn (device: Device, pInfo: *const DeviceMemoryOpaqueCaptureAddressInfo) callconv(.c) u64;
    pub const vkCmdDrawIndirectCount = *const fn (commandBuffer: CommandBuffer, buffer: Buffer, offset: DeviceSize, countBuffer: Buffer, countBufferOffset: DeviceSize, maxDrawCount: u32, stride: u32) callconv(.c) void;
    pub const vkCmdDrawIndexedIndirectCount = *const fn (commandBuffer: CommandBuffer, buffer: Buffer, offset: DeviceSize, countBuffer: Buffer, countBufferOffset: DeviceSize, maxDrawCount: u32, stride: u32) callconv(.c) void;
    pub const vkCreateRenderPass2 = *const fn (device: Device, pCreateInfo: *const RenderPassCreateInfo2, pAllocator: ?*const AllocationCallbacks, pRenderPass: *RenderPass) callconv(.c) Result;
    pub const vkCmdBeginRenderPass2 = *const fn (commandBuffer: CommandBuffer, pRenderPassBegin: *const RenderPassBeginInfo, pSubpassBeginInfo: *const SubpassBeginInfo) callconv(.c) void;
    pub const vkCmdNextSubpass2 = *const fn (commandBuffer: CommandBuffer, pSubpassBeginInfo: *const SubpassBeginInfo, pSubpassEndInfo: *const SubpassEndInfo) callconv(.c) void;
    pub const vkCmdEndRenderPass2 = *const fn (commandBuffer: CommandBuffer, pSubpassEndInfo: *const SubpassEndInfo) callconv(.c) void;
    pub const vkGetPhysicalDeviceToolProperties = *const fn (physicalDevice: PhysicalDevice, pToolCount: ?*u32, pToolProperties: ?[*]PhysicalDeviceToolProperties) callconv(.c) Result;
    pub const vkCreatePrivateDataSlot = *const fn (device: Device, pCreateInfo: *const PrivateDataSlotCreateInfo, pAllocator: ?*const AllocationCallbacks, pPrivateDataSlot: *PrivateDataSlot) callconv(.c) Result;
    pub const vkDestroyPrivateDataSlot = *const fn (device: Device, privateDataSlot: ?PrivateDataSlot, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkSetPrivateData = *const fn (device: Device, objectType: ObjectType, objectHandle: u64, privateDataSlot: PrivateDataSlot, data: u64) callconv(.c) Result;
    pub const vkGetPrivateData = *const fn (device: Device, objectType: ObjectType, objectHandle: u64, privateDataSlot: PrivateDataSlot, pData: *u64) callconv(.c) void;
    pub const vkCmdPipelineBarrier2 = *const fn (commandBuffer: CommandBuffer, pDependencyInfo: *const DependencyInfo) callconv(.c) void;
    pub const vkCmdWriteTimestamp2 = *const fn (commandBuffer: CommandBuffer, stage: PipelineStageFlags2, queryPool: QueryPool, query: u32) callconv(.c) void;
    pub const vkQueueSubmit2 = *const fn (queue: Queue, submitCount: u32, pSubmits: [*]const SubmitInfo2, fence: ?Fence) callconv(.c) Result;
    pub const vkCmdCopyBuffer2 = *const fn (commandBuffer: CommandBuffer, pCopyBufferInfo: *const CopyBufferInfo2) callconv(.c) void;
    pub const vkCmdCopyImage2 = *const fn (commandBuffer: CommandBuffer, pCopyImageInfo: *const CopyImageInfo2) callconv(.c) void;
    pub const vkCmdCopyBufferToImage2 = *const fn (commandBuffer: CommandBuffer, pCopyBufferToImageInfo: *const CopyBufferToImageInfo2) callconv(.c) void;
    pub const vkCmdCopyImageToBuffer2 = *const fn (commandBuffer: CommandBuffer, pCopyImageToBufferInfo: *const CopyImageToBufferInfo2) callconv(.c) void;
    pub const vkGetDeviceBufferMemoryRequirements = *const fn (device: Device, pInfo: *const DeviceBufferMemoryRequirements, pMemoryRequirements: *MemoryRequirements2) callconv(.c) void;
    pub const vkGetDeviceImageMemoryRequirements = *const fn (device: Device, pInfo: *const DeviceImageMemoryRequirements, pMemoryRequirements: *MemoryRequirements2) callconv(.c) void;
    pub const vkGetDeviceImageSparseMemoryRequirements = *const fn (device: Device, pInfo: *const DeviceImageMemoryRequirements, pSparseMemoryRequirementCount: ?*u32, pSparseMemoryRequirements: ?[*]SparseImageMemoryRequirements2) callconv(.c) void;
    pub const vkCmdSetEvent2 = *const fn (commandBuffer: CommandBuffer, event: Event, pDependencyInfo: *const DependencyInfo) callconv(.c) void;
    pub const vkCmdResetEvent2 = *const fn (commandBuffer: CommandBuffer, event: Event, stageMask: PipelineStageFlags2) callconv(.c) void;
    pub const vkCmdWaitEvents2 = *const fn (commandBuffer: CommandBuffer, eventCount: u32, pEvents: [*]const Event, pDependencyInfos: [*]const DependencyInfo) callconv(.c) void;
    pub const vkCmdBlitImage2 = *const fn (commandBuffer: CommandBuffer, pBlitImageInfo: *const BlitImageInfo2) callconv(.c) void;
    pub const vkCmdResolveImage2 = *const fn (commandBuffer: CommandBuffer, pResolveImageInfo: *const ResolveImageInfo2) callconv(.c) void;
    pub const vkCmdBeginRendering = *const fn (commandBuffer: CommandBuffer, pRenderingInfo: *const RenderingInfo) callconv(.c) void;
    pub const vkCmdEndRendering = *const fn (commandBuffer: CommandBuffer) callconv(.c) void;
    pub const vkCmdSetCullMode = *const fn (commandBuffer: CommandBuffer, cullMode: CullModeFlags) callconv(.c) void;
    pub const vkCmdSetFrontFace = *const fn (commandBuffer: CommandBuffer, frontFace: FrontFace) callconv(.c) void;
    pub const vkCmdSetPrimitiveTopology = *const fn (commandBuffer: CommandBuffer, primitiveTopology: PrimitiveTopology) callconv(.c) void;
    pub const vkCmdSetViewportWithCount = *const fn (commandBuffer: CommandBuffer, viewportCount: u32, pViewports: [*]const Viewport) callconv(.c) void;
    pub const vkCmdSetScissorWithCount = *const fn (commandBuffer: CommandBuffer, scissorCount: u32, pScissors: [*]const Rect2D) callconv(.c) void;
    pub const vkCmdBindVertexBuffers2 = *const fn (commandBuffer: CommandBuffer, firstBinding: u32, bindingCount: u32, pBuffers: ?[*]const Buffer, pOffsets: [*]const DeviceSize, pSizes: ?[*]const DeviceSize, pStrides: ?[*]const DeviceSize) callconv(.c) void;
    pub const vkCmdSetDepthTestEnable = *const fn (commandBuffer: CommandBuffer, depthTestEnable: Bool) callconv(.c) void;
    pub const vkCmdSetDepthWriteEnable = *const fn (commandBuffer: CommandBuffer, depthWriteEnable: Bool) callconv(.c) void;
    pub const vkCmdSetDepthCompareOp = *const fn (commandBuffer: CommandBuffer, depthCompareOp: CompareOp) callconv(.c) void;
    pub const vkCmdSetDepthBoundsTestEnable = *const fn (commandBuffer: CommandBuffer, depthBoundsTestEnable: Bool) callconv(.c) void;
    pub const vkCmdSetStencilTestEnable = *const fn (commandBuffer: CommandBuffer, stencilTestEnable: Bool) callconv(.c) void;
    pub const vkCmdSetStencilOp = *const fn (commandBuffer: CommandBuffer, faceMask: StencilFaceFlags, failOp: StencilOp, passOp: StencilOp, depthFailOp: StencilOp, compareOp: CompareOp) callconv(.c) void;
    pub const vkCmdSetRasterizerDiscardEnable = *const fn (commandBuffer: CommandBuffer, rasterizerDiscardEnable: Bool) callconv(.c) void;
    pub const vkCmdSetDepthBiasEnable = *const fn (commandBuffer: CommandBuffer, depthBiasEnable: Bool) callconv(.c) void;
    pub const vkCmdSetPrimitiveRestartEnable = *const fn (commandBuffer: CommandBuffer, primitiveRestartEnable: Bool) callconv(.c) void;
    pub const vkDestroySurfaceKHR = *const fn (instance: Instance, surface: ?SurfaceKHR, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkGetPhysicalDeviceSurfaceSupportKHR = *const fn (physicalDevice: PhysicalDevice, queueFamilyIndex: u32, surface: SurfaceKHR, pSupported: *Bool) callconv(.c) Result;
    pub const vkGetPhysicalDeviceSurfaceCapabilitiesKHR = *const fn (physicalDevice: PhysicalDevice, surface: SurfaceKHR, pSurfaceCapabilities: *SurfaceCapabilitiesKHR) callconv(.c) Result;
    pub const vkGetPhysicalDeviceSurfaceFormatsKHR = *const fn (physicalDevice: PhysicalDevice, surface: ?SurfaceKHR, pSurfaceFormatCount: ?*u32, pSurfaceFormats: ?[*]SurfaceFormatKHR) callconv(.c) Result;
    pub const vkGetPhysicalDeviceSurfacePresentModesKHR = *const fn (physicalDevice: PhysicalDevice, surface: ?SurfaceKHR, pPresentModeCount: ?*u32, pPresentModes: ?[*]PresentModeKHR) callconv(.c) Result;
    pub const vkCreateSwapchainKHR = *const fn (device: Device, pCreateInfo: *const SwapchainCreateInfoKHR, pAllocator: ?*const AllocationCallbacks, pSwapchain: *SwapchainKHR) callconv(.c) Result;
    pub const vkDestroySwapchainKHR = *const fn (device: Device, swapchain: ?SwapchainKHR, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkGetSwapchainImagesKHR = *const fn (device: Device, swapchain: SwapchainKHR, pSwapchainImageCount: ?*u32, pSwapchainImages: ?[*]Image) callconv(.c) Result;
    pub const vkAcquireNextImageKHR = *const fn (device: Device, swapchain: SwapchainKHR, timeout: u64, semaphore: ?Semaphore, fence: ?Fence, pImageIndex: *u32) callconv(.c) Result;
    pub const vkQueuePresentKHR = *const fn (queue: Queue, pPresentInfo: *const PresentInfoKHR) callconv(.c) Result;
    pub const vkGetDeviceGroupPresentCapabilitiesKHR = *const fn (device: Device, pDeviceGroupPresentCapabilities: *DeviceGroupPresentCapabilitiesKHR) callconv(.c) Result;
    pub const vkGetDeviceGroupSurfacePresentModesKHR = *const fn (device: Device, surface: SurfaceKHR, pModes: ?*DeviceGroupPresentModeFlagsKHR) callconv(.c) Result;
    pub const vkGetPhysicalDevicePresentRectanglesKHR = *const fn (physicalDevice: PhysicalDevice, surface: SurfaceKHR, pRectCount: ?*u32, pRects: ?[*]Rect2D) callconv(.c) Result;
    pub const vkAcquireNextImage2KHR = *const fn (device: Device, pAcquireInfo: *const AcquireNextImageInfoKHR, pImageIndex: *u32) callconv(.c) Result;
    pub const vkSetDebugUtilsObjectNameEXT = *const fn (device: Device, pNameInfo: *const DebugUtilsObjectNameInfoEXT) callconv(.c) Result;
    pub const vkSetDebugUtilsObjectTagEXT = *const fn (device: Device, pTagInfo: *const DebugUtilsObjectTagInfoEXT) callconv(.c) Result;
    pub const vkQueueBeginDebugUtilsLabelEXT = *const fn (queue: Queue, pLabelInfo: *const DebugUtilsLabelEXT) callconv(.c) void;
    pub const vkQueueEndDebugUtilsLabelEXT = *const fn (queue: Queue) callconv(.c) void;
    pub const vkQueueInsertDebugUtilsLabelEXT = *const fn (queue: Queue, pLabelInfo: *const DebugUtilsLabelEXT) callconv(.c) void;
    pub const vkCmdBeginDebugUtilsLabelEXT = *const fn (commandBuffer: CommandBuffer, pLabelInfo: *const DebugUtilsLabelEXT) callconv(.c) void;
    pub const vkCmdEndDebugUtilsLabelEXT = *const fn (commandBuffer: CommandBuffer) callconv(.c) void;
    pub const vkCmdInsertDebugUtilsLabelEXT = *const fn (commandBuffer: CommandBuffer, pLabelInfo: *const DebugUtilsLabelEXT) callconv(.c) void;
    pub const vkCreateDebugUtilsMessengerEXT = *const fn (instance: Instance, pCreateInfo: *const DebugUtilsMessengerCreateInfoEXT, pAllocator: ?*const AllocationCallbacks, pMessenger: *DebugUtilsMessengerEXT) callconv(.c) Result;
    pub const vkDestroyDebugUtilsMessengerEXT = *const fn (instance: Instance, messenger: ?DebugUtilsMessengerEXT, pAllocator: ?*const AllocationCallbacks) callconv(.c) void;
    pub const vkSubmitDebugUtilsMessageEXT = *const fn (instance: Instance, messageSeverity: DebugUtilsMessageSeverityFlagsEXT, messageTypes: DebugUtilsMessageTypeFlagsEXT, pCallbackData: *const DebugUtilsMessengerCallbackDataEXT) callconv(.c) void;
};
