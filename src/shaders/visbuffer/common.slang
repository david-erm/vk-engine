module common;

import "../desc";
import "../structs";
#include "defines.slang"

#ifdef MATERIAL_SHADER_IMPL

float4 pixelShade(Push *push, Vertex v, uint32_t draw_id, Derivatives d);

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

    const int32_t3 face = push.indices[triangle_id + off.start_index / 3]; 
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

    const float2 uv = InterpolateXY(bary.lambda, vertices[0].uv, vertices[1].uv, vertices[2].uv);
    const float2 uv_grad_x = InterpolateXY(bary.ddx, vertices[0].uv, vertices[1].uv, vertices[2].uv);
    const float2 uv_grad_y = InterpolateXY(bary.ddy, vertices[0].uv, vertices[1].uv, vertices[2].uv);

    const float3 pos = InterpolateXYZ(bary.lambda, vertices[0].pos, vertices[1].pos, vertices[2].pos);
    const float3 pos_gradx = InterpolateXYZ(bary.ddx, vertices[0].pos, vertices[1].pos, vertices[2].pos);
    const float3 pos_grady = InterpolateXYZ(bary.ddy, vertices[0].pos, vertices[1].pos, vertices[2].pos);

    const float3 norm = InterpolateXYZ(bary.lambda, vertices[0].norm, vertices[1].norm, vertices[2].norm);

    const Vertex v = {pos, norm, uv};
    const Derivatives d = {
        float2x2(uv_grad_x, uv_grad_y),
        float2x3(pos_gradx, pos_grady),
    };
    
    float4 output = pixelShade(&push, v, instance_id, d);
    offscreen[sample_pair].rgb = (offscreen[sample_pair].rgb * offscreen[sample_pair].a) + output.rgb * (1.0 - offscreen[sample_pair].a); 
}

#endif // #ifdef MATERIAL_SHADER_IMPL

public float3 calcNormals(float3 tangent_normals, float3 pos, float2 UV, float3 vertex_normals, Derivatives d)
{
    const float3 N = normalize(vertex_normals);
    const float3 T = normalize(d.pos[0]*d.uv[1].y - d.pos[1]*d.uv[0].y);
    const float3 B = -normalize(cross(N, T));
    const float3x3 TBN = float3x3(T, B, N);

    return normalize(mul(tangent_normals, TBN));
}

public struct Derivatives {
    public float2x2 uv;
    public float2x3 pos;
};

struct BarycentricDeriv {
    float3 lambda;
    float3 ddx;
    float3 ddy;  
};

float3 InterpolateWithDeriv(BarycentricDeriv deriv, float v0, float v1, float v2) {
    const float3 v = float3(v0, v1, v2);
    const float3 ret = float3(
        dot(v, deriv.lambda),
        dot(v, deriv.ddx),
        dot(v, deriv.ddy)
    ); 
    return ret;
}

float Interpolate(float3 lambda, float v0, float v1, float v2) {
    return dot(float3(v0, v1, v2), lambda);
}

float3 InterpolateXYZ(float3 lambda, float3 v0, float3 v1, float3 v2) {
    return mul(lambda, float3x3(v0, v1, v2));
}

float2 InterpolateXY(float3 lambda, float2 v0, float2 v1, float2 v2) {
    return mul(lambda, float3x2(v0, v1, v2));
}

// https://filmicworlds.com/blog/visibility-buffer-rendering-with-material-graphs/
BarycentricDeriv CalcFullBary(float4 pt0, float4 pt1, float4 pt2, float2 pixel_ndc, float2 win_size) {
    BarycentricDeriv ret = (BarycentricDeriv)0;

    const float3 invW = rcp(float3(pt0.w, pt1.w, pt2.w));

    const float2 ndc0 = pt0.xy * invW.x;
    const float2 ndc1 = pt1.xy * invW.y;
    const float2 ndc2 = pt2.xy * invW.z;

    const float invDet = rcp(determinant(float2x2(ndc2 - ndc1, ndc0 - ndc1)));
    ret.ddx = float3(ndc1.y - ndc2.y, ndc2.y - ndc0.y, ndc0.y - ndc1.y) * invDet * invW;
    ret.ddy = float3(ndc2.x - ndc1.x, ndc0.x - ndc2.x, ndc1.x - ndc0.x) * invDet * invW;

    float ddx_sum = dot(ret.ddx, float3(1));
    float ddy_sum = dot(ret.ddy, float3(1));
    
    const float2 delta_vec = pixel_ndc - ndc0;
    const float interp_invw = invW.x + delta_vec.x*ddx_sum + delta_vec.y*ddy_sum;
    const float interpW = rcp(interp_invw);

    ret.lambda.x = interpW * (invW[0] + delta_vec.x*ret.ddx.x + delta_vec.y*ret.ddy.x);
    ret.lambda.y = interpW * (0.0f    + delta_vec.x*ret.ddx.y + delta_vec.y*ret.ddy.y);
    ret.lambda.z = interpW * (0.0f    + delta_vec.x*ret.ddx.z + delta_vec.y*ret.ddy.z);

    ret.ddx *= (2.0/win_size.x);
    ret.ddy *= (2.0/win_size.y);
    ddx_sum *= (2.0/win_size.x);
    ddy_sum *= (2.0/win_size.y);

    // NOTE: We are on vulkan, so y is flipped. Leaving this here for sanity
     // ret.ddy *= -1.0;
     // ddy_sum *= -1.0;

    const float interW_ddx = 1.0 / (interp_invw + ddx_sum);
    const float interW_ddy = 1.0 / (interp_invw + ddy_sum);

    ret.ddx = interW_ddx*(ret.lambda*interp_invw + ret.ddx) - ret.lambda;
    ret.ddy = interW_ddy*(ret.lambda*interp_invw + ret.ddy) - ret.lambda;

    return ret;
}
