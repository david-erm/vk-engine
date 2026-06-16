import desc;
import structs;
import pbrutils;

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

    Pose pose = push.poses[iid];
    Pose cam = push.scene.cam;

    float3 frag_pos = cam.toFrame(pose.transform(v.pos));
    output.Normal = rotate(v.norm, qmul(conj(cam.rot), pose.rot));
    output.LightVec = rotate(push.scene.lightPos.xyz - cam.pos.xyz, conj(cam.rot)) - frag_pos;

    output.Pos = mul(push.scene.projection, float4(frag_pos, 1.0));
    output.ViewVec  = -frag_pos;

    output.mat = push.materials[iid];
    output.UV = v.uv;
    
    return output;

};

static const float3 light_color = float3(30.4, 31.0, 30.3);
[shader("fragment")]
float4 main(VSOut input) {
    float3 N;
    if (input.mat.normal != (1 << 32) - 1) {
        const float2 raw_n = sampled[NonUniformResourceIndex(input.mat.normal)].Sample(samplers[0], input.UV).rg; 
        N = normalsToViewSpace(restoreNormal(raw_n), -input.ViewVec, input.UV, input.Normal);
    } else {
        N = normalize(input.Normal);
        return float4(float3(0.1, 0.0, 0.0), 1.0);
    }
    const float3 V = normalize(input.ViewVec);

    const float3 albedo = sampled[NonUniformResourceIndex(input.mat.albedo)].Sample(samplers[0], input.UV).rgb;
    // const float ao = sampled[NonUniformResourceIndex(input.mat.occlusion)].Sample(samplers[0], input.UV).r;
    const float2 metallic_roughness = sampled[NonUniformResourceIndex(input.mat.metallic_roughness)].Sample(samplers[0], input.UV).rg;
    
    //per light
    const float3 L = normalize(input.LightVec);
    const float3 H = normalize(V + L);
    const float d = length(input.LightVec);
    const float3 radiance = (1 / (d * d)) * light_color;

    const float NdotL = max(dot(N, L), 0.0);
    const float NdotV = max(dot(N, V), 0.0);

    //pbr    
    const float NDF = distributionGGX(N, H, metallic_roughness.r);
    const float G = geometrySmith(NdotV, NdotL, metallic_roughness.r);
    const float3 F = lerp(F0, albedo, metallic_roughness.g);
    const float3 fres = fresnelSchlick(max(dot(N, V), 0.0), F);

    const float3 kD = (float3(1.0) - fres) * (1.0 - metallic_roughness.g);

    const float3 numerator = NDF * G * F;
    const float denominator = (4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0)) + 0.0001;
    const float3 specular = numerator / denominator;

    const float3 Lo = (kD * albedo / float.getPi() + specular) * radiance * NdotL;
    
    return float4(Lo, 1.0);
}
