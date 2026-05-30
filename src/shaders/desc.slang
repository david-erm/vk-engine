module desc;

//binding 0
[vk::binding(0, 0)] public Texture2D sampled[];
[vk::binding(0, 0)] public TextureCube cubes[];

//binding 1
[vk::binding(1, 0)] public RWTexture2D images[];

//binding 2
[vk::binding(2, 0)] public SamplerState samplers[];
