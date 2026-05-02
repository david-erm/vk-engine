import util;

struct VSOut {
  float4 Pos : SV_Position;
  float3 vector;
};

[vk::binding(0, 0)] TextureCube skybox[];

[shader("vertex")]
VSOut main(float3 inputpos, uniform ShaderData* shaderData)
{
  VSOut output;
  output.Pos = mul(shaderData->projection, float4(rotate(inputpos, conj(shaderData->cam.rot)), 1));     
  output.vector = inputpos;
}

[shader("fragment")]
float4 main(VSOut input)
{
    
}
