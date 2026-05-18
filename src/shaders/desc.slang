module desc;

//binding 0
[vk::binding(0, 0)] public Sampler2D sampled[];
[vk::binding(0, 0)] public Sampler2D<uint8_t> usampled[];
[vk::binding(0, 0)] public Texture2D textures[];
[vk::binding(0, 0)] public SamplerCube cubes[];

//binding 1
[vk::binding(1, 0)] public RWTexture2D images[];
