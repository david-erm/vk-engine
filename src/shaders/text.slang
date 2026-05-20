import desc;
import util;

struct VSOut {
    float4 Pos : SV_Position;
    float2 tex_coords;
};

// static float2 quad[6] = {
//     float2(0.0, 0.0),
//     float2(0.0, 1.0),
//     float2(1.0, 1.0),
//     float2(0.0, 0.0),
//     float2(1.0, 1.0),
//     float2(1.0, 0.0),
// }; 

[shader("vertex")]
VSOut main(float4 vertex, uniform ShaderData* shader_data) {
    // float2 vertex = quad[vid];
    VSOut output;

    output.Pos = mul(shader_data->ortho, float4(vertex.xy, 0.0, 1.0));
    output.tex_coords = vertex.zw;
    
    return output;
}

[shader("fragment")]
float4 main(VSOut input) {
    float color = sampled[NonUniformResourceIndex(4)].Sample(input.tex_coords).r;
    return float4(0.0, 0.8, 0.2, 1.0) * color;
}

