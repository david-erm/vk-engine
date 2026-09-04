import "../desc";
import "../structs";
import "../pbrutils.slang";
import "../util.slang";

#define MATERIAL_SHADER_IMPL
#include "common.slang"

public float4 pixelShade(Push* push, Vertex v, uint32_t draw_id, Derivatives d) {
    const Material mat = push.materials[draw_id];
    //FIX: ignoring transparency
    const float3 albedo = sampled[NonUniformResourceIndex(mat.albedo)].SampleGrad(samplers[0], v.uv, d.uv[0], d.uv[1]).rgb;

    const float2 raw_n = sampled[NonUniformResourceIndex(mat.normal)].SampleGrad(samplers[0], v.uv, d.uv[0], d.uv[1]).rg;
    const float2 roughness_metallic = sampled[NonUniformResourceIndex(mat.metallic_roughness)].SampleGrad(samplers[0], v.uv, d.uv[0], d.uv[1]).rg;

    const Scene scene = push.scene[push.fif_index];
    const Pose pose = push.poses[draw_id];

    const float3 world_pos = pose.transform(v.pos);
    const float3 world_normals = rotate(v.norm, pose.rot);

    //per material
    const float3 N = calcNormals(restoreNormal(raw_n), world_pos, v.uv, world_normals, d);
    const float3 V = normalize(scene.cam.pos.xyz - world_pos);
    const float3 F0 = lerp(F0base, albedo, roughness_metallic.g);
    //used many times
    const float NdotV = max(dot(N, V), 0.0);

    //per light
    const float3 L = normalize(scene.lightPos.xyz - world_pos);
    const float distance = length(scene.lightPos.xyz - world_pos);
    const float3 H = normalize(V + L);
    // const float attenuation = (1 / (distance * distance)) * 10.0;
    const float radius = 0.5;
    // const float attenuation = (1 / (1 + ((2 * distance) / radius) + ((distance * distance) / (radius * radius)) ));
    const float kl = (2 / radius) * distance;
    const float ks = ((distance * distance) / (radius * radius));
    const float attenuation = 10.0 / (1 + kl + ks) * 5.0;
    //used many times
    const float NdotL = max(dot(N, L), 0.0);

    const float3 F = fresnelSchlick(clamp(dot(H, V), 0.0, 1.0), F0);
    const float3 kD = (float3(1.0) - F) * (1.0 - roughness_metallic.g); 

    const float NDF = distributionGGX(N, H, roughness_metallic.r);
    const float G = geometrySmith(NdotV, NdotL, roughness_metallic.r);

    const float3 numerator = NDF * G * F;
    const float3 denominator = (4.0 * NdotV * NdotL) + 0.0001;
    const float3 specular = numerator / denominator;

    const float3 Lo = (kD * albedo / float.getPi() + specular) * attenuation * NdotL;

    return float4(PBRNeutralToneMapping(Lo), 1.0);
    // return float4(0.5, 0.5, 0.0, 1.0);
}
