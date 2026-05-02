module util;

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

//Struct definitions

public struct Pose {
    public float4 pos;
    public float4 rot;
};

public struct ShaderData {
    public float4x4 projection;
    public Pose cam;
    public Pose poses[5];
    public float4 lightPos;
    public uint32_t selected;
};
