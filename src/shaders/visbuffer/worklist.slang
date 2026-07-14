import "../structs";
import "../desc.slang";
import common;

#include "defines.slang"

groupshared uint shader_present_in_tile[MAT_SHADER_NUM];
[shader("compute")]
[numthreads(TILE_SIZE_X, TILE_SIZE_Y, 1)]
void main(uniform Push push, uint2 group_id : SV_GroupID, uint2 local_id : SV_GroupThreadID, uint2 global_id : SV_DispatchThreadID) {
    const uint local_idx = local_id.x + local_id.y * TILE_SIZE_X;
    const uint tile_index_packed = (group_id.y << 16) | (group_id.x);
    const uint global_index = global_id.x + global_id.y * push.scene[push.fif_index].dimensions.x;

    //global init
    if (global_index < MAT_SHADER_NUM) {
        Scene scene = push.scene[push.fif_index];
        push.material_params[global_index].group_size = {0, 1, 1};  
    }

    uint32_t2* data = (uint32_t2*)push.user_buffer;
    const uint32_t2 indices = data[push.fif_index];

    RWTexture2D offscreen = storage[indices.y];
    const uint32_t visbuffer = u32sampled[indices.x][global_id].r; 

    //init shared
    if (local_idx == 0) {
        for (int i = 0; i < MAT_SHADER_NUM; i++) {
            shader_present_in_tile[i] = 0;
        }
    };
    GroupMemoryBarrierWithGroupSync();

    //FIX: make it actually use draw_id perhaps?
    //FIX: lookup table
    if (visbuffer == uint32_t.maxValue) {
        InterlockedOr(shader_present_in_tile[0], 1);
    } else {
        InterlockedOr(shader_present_in_tile[1], 1);
    }
    GroupMemoryBarrierWithGroupSync();

    uint32_t shader_id = local_idx;
    if (shader_id == 0) return;
    while (shader_id < MAT_SHADER_NUM) {
        if (shader_present_in_tile[shader_id] > 0) {
            InterlockedAdd(push.material_params[shader_id].group_size.x, 1);
            uint32_t idx = 0; 
            InterlockedAdd(push.tiles[0].x, 1, idx);
            push.tiles[idx + 1].x = tile_index_packed;
            push.tiles[idx + 1].y = shader_id;
        }
        shader_id += TILE_SIZE_X * TILE_SIZE_Y;
    }

}
