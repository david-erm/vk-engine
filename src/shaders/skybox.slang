import util;
import desc;


struct VSOutput {
    float4 Pos : SV_POSITION;
    float3 local_pos;
    uint index;
};


[shader("vertex")]
VSOutput main(float3 pos, uniform Push push, uint iidx : SV_VulkanInstanceID)
{
    VSOutput output;
    Pose cam = push.scene.cam;

    output.local_pos = rotate(pos, cam.rot);
    output.Pos = float4(pos, 1.0).xyww;
    output.index = push.materials[iidx].albedo;
    
    return output;
}

[shader("fragment")]
float4 main(VSOutput input)
{
    input.local_pos.y = -input.local_pos.y;
    return cubes[NonUniformResourceIndex(input.index)].Sample(input.local_pos);
}

