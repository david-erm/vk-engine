//NOTE: this has to be maintained in sync with src/renderer/structs.zig
module structs;
__exported import util;

public struct Material {
    public uint albedo;  
    public uint metallic_roughness;  
    public uint normal;  
    public uint occlusion;  
    public uint emissive;  
};

public struct Pose {
    public float3 pos;
    public float extra;
    public float4 rot;

    public float3 transform(float3 input) {
        return rotate(input, rot) + pos;
    }

    public float3 toFrame(float3 input) {
        return rotate(input - pos, conj(rot));
    }
};

public struct Scene {
    public float4x4 projection;
    public float4x4 ortho;
    public Pose cam; 
    public float4 lightPos;
    public uint32_t selected;
    // public float delta_time;
};

public struct Vertex {
    public float3 pos;
    public float3 norm;
    public float2 uv;
};

public struct Push {
    public Scene* scene; 
    public Pose* poses;
    public Material* materials;
    public Vertex* vertices;
    public uint64_t fif_index;
};
