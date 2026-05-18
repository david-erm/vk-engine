import desc;
import util;


struct VSInput {
    float4 vertex;  
};

struct VSOut {
    float4 Pos : SV_Position;
    float2 tex_coords;
    uint instance;
};

[shader("vertex")]
VSOut main(VSInput input, uniform ShaderData* shader_data, uint instance : SV_VulkanInstanceID) {
    VSOut output;
    output.Pos = mul(shader_data->ortho, float4(input.vertex.xy, 0.0, 1.0));
    output.tex_coords = input.vertex.zw;
    output.instance = instance;
    
    return output;
}

[shader("fragment")]
float4 main(VSOut input) {
    uint8_t color = usampled[NonUniformResourceIndex(4 + input.instance)].Sample(input.tex_coords).r;
    if (color < 128) {
        discard;
    }
    return float4(0.0, 0.8, 0.2, 1.0);
}

