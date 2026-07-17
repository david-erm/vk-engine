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
    public uint32_t2 dimensions;
    public uint32_t selected;
};

public struct Offsets {
    public uint32_t start_index;  
    public uint32_t index_count;
    public uint32_t start_vertex;
};

public struct Vertex {
    public float3 pos;
    public float3 norm;
    public float2 uv;
};

public struct DispatchIndirectCommand {
    public uint32_t x;
    public uint32_t y;
    public uint32_t z;
};


public struct Push {
    public Scene* scene;  // 8
    public Pose* poses; // 16
    public Material* materials; // 24
    public Vertex* vertices; // 32
    public uint32_t3* indices; // 40
    public Offsets* offsets; // 48
    public DispatchIndirectCommand* material_params; // 56
    public void* user_buffer; // 64
    public uint32_t2* tiles; // 72
    public uint32_t fif_index; 
    private uint32_t pad; // 80
};
