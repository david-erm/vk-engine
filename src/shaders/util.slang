module util;

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

public struct Vertex {
    public float3 pos;
    public float u;
    public float3 norm;
    public float v;
};

public struct Scene {
    public float4x4 projection;
    public float4x4 ortho;
    public Pose cam; 
    public float4 lightPos;
    public uint32_t selected;
    // public float delta_time;
};

public struct Push {
    public Scene* scene; 
    public Pose* poses;
    public Material* materials;
    public Vertex* vertices;
};

//Quat operations
public float4 qmul(float4 q1, float4 q2) {
    float4 q3;
    q3.xyz = q1.w * q2.xyz + q2.w * q1.xyz + cross(q1.xyz, q2.xyz);
    q3.w = q1.w * q2.w - dot(q1.xyz, q2.xyz);
    return q3;
} 

public float4 conj(float4 q1) {
    return float4(-q1.xyz, q1.w);
}

public float3 rotate(float3 v, float4 q) {
    float4 vq = float4(v, 0);
    return qmul(qmul(q, vq), conj(q)).xyz;
}

