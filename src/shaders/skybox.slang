import util;
import desc;


struct VSOutput {
    float4 Pos : SV_POSITION;
    float3 local_pos;
};


[shader("vertex")]
VSOutput main(float3 pos, uniform ShaderData *shaderData)
{
    VSOutput output;
    Pose cam = shaderData->cam;

    output.local_pos = rotate(pos, cam.rot);
    output.Pos = float4(pos, 1.0).xyww;
    
    return output;
}

[shader("fragment")]
float4 main(VSOutput input)
{
    input.local_pos.y = -input.local_pos.y;
    return cubes[NonUniformResourceIndex(3)].Sample(input.local_pos);
}

