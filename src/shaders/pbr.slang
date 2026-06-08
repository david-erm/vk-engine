import desc;
import util;

struct VSOut {
    float4 Pos : SV_POSITION;
    float3 Normal;
    float2 UV;
    float3 LightVec;
    float3 ViewVec;
    Material mat;  
};

[shader("vertex")]
VSOut main(uniform Push push, uint vid : SV_VulkanVertexID, uint iid : SV_VulkanInstanceID) {
    VSOut output;
    Vertex v = push.vertices[vid];
    float2 uv = float2(v.u, v.v);

    Pose pose = push.poses[iid];
    Pose cam = push.scene.cam;

    float3 frag_pos = cam.toFrame(pose.transform(v.pos));
    output.Normal = rotate(v.norm, qmul(conj(cam.rot), pose.rot));
    output.LightVec = rotate(push.scene.lightPos.xyz - cam.pos.xyz, conj(cam.rot)) - frag_pos;

    output.Pos = mul(push.scene.projection, float4(frag_pos, 1.0));
    output.ViewVec  = -frag_pos;

    output.mat = push.materials[iid];
    output.UV = uv;
    
    return output;

};

[shader("fragment")]
float4 main(VSOut input) {
    float3 N;
    if (input.mat.normal != (1 << 32) - 1) {
        float2 raw_n = sampled[input.mat.normal].Sample(samplers[0], input.UV).rg; 
        N = normalsToViewSpace(restoreNormal(raw_n), -input.ViewVec, input.UV, input.Normal);
    } else {
        N = normalize(input.Normal);
    }
    const float3 L = normalize(input.LightVec);
    const float3 V = normalize(input.ViewVec);
    const float3 R = reflect(-L, N);
    const float3 diffuse = max(dot(N, L), 0.0025);
    const float3 specular = pow(max(dot(R, V), 0.00001), 64.0) * 0.75;

    const float d = distance(-input.ViewVec, input.LightVec);
    const float intensity = (1 / (d * d)) * 10.0;

    float3 color;
    color = sampled[NonUniformResourceIndex(input.mat.albedo)].Sample(samplers[0], input.UV).rgb;
    return float4(color.rgb * (diffuse + specular) * intensity, 1.0);
    // return float4(sampled[input.mat.metallic_roughness].Sample(samplers[0], input.UV).rgb, 1.0);
}
