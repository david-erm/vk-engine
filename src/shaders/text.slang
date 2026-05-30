import desc;
import util;

struct VSOut {
    float4 Pos : SV_Position;
    float2 tex_coords;
};

[shader("vertex")]
VSOut main(float4 vertex, uniform Push push) {
    // float2 vertex = quad[vid];
    VSOut output;

    output.Pos = mul(push.scene.ortho, float4(vertex.xy, 0.0, 1.0));
    output.tex_coords = vertex.zw;
    
    return output;
}

[shader("fragment")]
float4 main(VSOut input) {
    float color = sampled[NonUniformResourceIndex(4)].Sample(samplers[0], input.tex_coords).r;
    return float4(0.0, 0.8, 0.2, 1.0) * color;
}

