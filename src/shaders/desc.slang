module desc;

//binding 0
[vk::binding(0, 0)] public Texture2D sampled[];
[vk::binding(0, 0)] public Texture2D<uint32_t> u32sampled[];
[vk::binding(0, 0)] public TextureCube cubes[];

//binding 1
[vk::binding(1, 0)] public RWTexture2D storage[];

//binding 2
[vk::binding(2, 0)] public SamplerState samplers[];
