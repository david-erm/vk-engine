import "../desc";
import "../structs";
import "../pbrutils.slang";
import "../util.slang";

import common;

#include "defines.slang"

float4 pixelShade(Push* push, Vertex v, uint32_t draw_id, Derivatives d) {
    Material mat = push.materials[draw_id];
    //FIX: ignoring transparency
    const float3 albedo = sampled[NonUniformResourceIndex(mat.albedo)].SampleGrad(samplers[0], v.uv, d.uv[0], d.uv[1]).rgb;

    const float2 raw_n = sampled[NonUniformResourceIndex(mat.normal)].SampleGrad(samplers[0], v.uv, d.uv[0], d.uv[1]).rg;
    const float2 roughness_metallic = sampled[NonUniformResourceIndex(mat.metallic_roughness)].SampleGrad(samplers[0], v.uv, d.uv[0], d.uv[1]).rg;

    Scene scene = push.scene[push.fif_index];
    Pose pose = push.poses[draw_id];

    const float3 world_pos = pose.transform(v.pos);
    const float3 world_normals = rotate(v.norm, pose.rot);

    //per material
    const float3 N = calcNormals(restoreNormal(raw_n), world_pos, v.uv, world_normals, d);
    const float3 V = scene.cam.pos.xyz - world_pos;
    const float3 F0 = lerp(F0base, albedo, roughness_metallic.g);
    //used many times
    const float NdotV = max(dot(N, V), 0.0);

    //per light
    const float3 L = scene.lightPos.xyz - world_pos;
    const float3 H = normalize(V + L);
    const float distance = length(L);
    const float attenuation = 1 / (distance * distance) * 10.0;
    //used many times
    const float NdotL = max(dot(N, L), 0.0);

    const float3 F = fresnelSchlick(clamp(dot(H, V), 0.0, 1.0), F0);
    const float3 kD = (float3(1.0) - F) * (1.0 - roughness_metallic.g); 

    const float3 NDF = distributionGGX(N, H, roughness_metallic.r);
    const float3 G = geometrySmith(NdotV, NdotL, roughness_metallic.r);

    const float3 numerator = NDF * G * F;
    const float3 denominator = (4.0 * NdotV * NdotL) + 0.0001;
    const float3 specular = numerator / denominator;

    const float3 Lo = (kD * albedo / float.getPi() + specular) * attenuation * NdotL;

    return float4(PBRNeutralToneMapping(Lo), 1.0);
}

[shader("compute")]
[numthreads(TILE_SIZE_X, TILE_SIZE_Y, 1)]
void main(uint2 id_local : SV_GroupThreadID, uint2 gid : SV_GroupID, uniform Push push) {
    uint32_t2* data = (uint32_t2*)push.user_buffer;
    const uint32_t2 indices = data[push.fif_index];
    RWTexture2D offscreen = storage[indices.y];

    const uint32_t2 offsets = push.tiles[gid.x + 1];
    if (offsets.y != 1) return; 
    
    const uint32_t2 tile_idx = {offsets.x & 0xFFFF, offsets.x >> 16}; 
    const uint32_t2 sample_pair = {
        (tile_idx.x * TILE_SIZE_X) + id_local.x,
        (tile_idx.y * TILE_SIZE_Y) + id_local.y
    }; 

    const uint32_t visbuffer = u32sampled[indices.x][sample_pair].r;

    const uint32_t triangle_id = visbuffer >> DRAW_ID_BITS;
    const uint32_t instance_id = visbuffer & 0xff;

    const Offsets off = push.offsets[instance_id];

    const Scene scene = push.scene[push.fif_index];
    const Pose pose = push.poses[instance_id];

    const uint32_t3 face = push.indices[triangle_id + off.start_index / 3]; 
    Vertex vertices[3];
    vertices[0] = push.vertices[face.x + off.start_vertex];
    vertices[1] = push.vertices[face.y + off.start_vertex];
    vertices[2] = push.vertices[face.z + off.start_vertex];

    float4 pixel_pos[3];
    pixel_pos[0] = mul(scene.projection, float4(scene.cam.toFrame(pose.transform(vertices[0].pos)), 1.0));
    pixel_pos[1] = mul(scene.projection, float4(scene.cam.toFrame(pose.transform(vertices[1].pos)), 1.0));
    pixel_pos[2] = mul(scene.projection, float4(scene.cam.toFrame(pose.transform(vertices[2].pos)), 1.0));

    float2 pixel_ndc = float2(sample_pair + 0.5) / scene.dimensions;
    pixel_ndc = pixel_ndc * 2.0 - 1.0;

    const BarycentricDeriv bary = CalcFullBary(pixel_pos[0], pixel_pos[1], pixel_pos[2], pixel_ndc, scene.dimensions);

    const float3 interpolated_u = InterpolateWithDeriv(bary, vertices[0].uv.x, vertices[1].uv.x, vertices[2].uv.x);
    const float3 interpolated_v = InterpolateWithDeriv(bary, vertices[0].uv.y, vertices[1].uv.y, vertices[2].uv.y);

    const float2 UV = float2(interpolated_u.x, interpolated_v.x);
    const float2 grad_x = float2(interpolated_u.y, interpolated_v.y);
    const float2 grad_y = float2(interpolated_u.z, interpolated_v.z);

    const float3 interpolated_posx = InterpolateWithDeriv(bary, vertices[0].pos.x, vertices[1].pos.x, vertices[2].pos.x);
    const float3 interpolated_posy = InterpolateWithDeriv(bary, vertices[0].pos.y, vertices[1].pos.y, vertices[2].pos.y);
    const float3 interpolated_posz = InterpolateWithDeriv(bary, vertices[0].pos.z, vertices[1].pos.z, vertices[2].pos.z);

    const float3 pos = float3(interpolated_posx.x, interpolated_posy.x, interpolated_posz.x);
    const float3 pos_gradx = float3(interpolated_posx.y, interpolated_posy.y, interpolated_posz.y);
    const float3 pos_grady = float3(interpolated_posx.z, interpolated_posy.z, interpolated_posz.z);

    const float3 interpolated_normx = InterpolateWithDeriv(bary, vertices[0].norm.x, vertices[1].norm.x, vertices[2].norm.x);
    const float3 interpolated_normy = InterpolateWithDeriv(bary, vertices[0].norm.y, vertices[1].norm.y, vertices[2].norm.y);
    const float3 interpolated_normz = InterpolateWithDeriv(bary, vertices[0].norm.z, vertices[1].norm.z, vertices[2].norm.z);

    const float3 norm = float3(interpolated_normx.x, interpolated_normy.x, interpolated_normz.x);

    const Vertex v = {pos, norm, UV};
    const Derivatives d = {
        float2x2(grad_x, grad_y),
        float2x3(pos_gradx, pos_grady),
    };
    
    float4 out = pixelShade(&push, v, instance_id, d);
    offscreen[sample_pair].rgb = (offscreen[sample_pair].rgb * offscreen[sample_pair].a) + out.rgb * (1.0 - offscreen[sample_pair].a); 
}

float3 calcNormals(float3 tangent_normals, float3 pos, float2 UV, float3 vertex_normals, Derivatives d)
{
    const float3 N = normalize(vertex_normals);
    const float3 T = normalize(d.pos[0]*d.uv[1].y - d.pos[1]*d.uv[0].y);
    const float3 B = -normalize(cross(N, T));
    const float3x3 TBN = float3x3(T, B, N);

    return normalize(mul(tangent_normals, TBN));
}

struct Derivatives {
    float2x2 uv;
    float2x3 pos;
};

