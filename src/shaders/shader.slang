import util;

struct VSInput {
    float3 Pos;
    float3 Normal;
    float2 uv;
};

struct ShaderData {
    float4x4 projection;
    Camera cam;
    float4 pos[3];
    float4 quat;
    float4 lightPos;
    uint32_t selected;
};

struct VSOutput {
    float4 Pos : SV_POSITION;
    float3 Normal;
    float2 UV;
    float3 factor;
    float3 LightVec;
    float3 ViewVec;
    uint32_t instanceIndex;
};

[vk::binding(0, 0)] Sampler2D textures[];
// [vk::binding(0, 1)] Sampler2D samplers[];

[shader("vertex")]
VSOutput main(VSInput input, uniform ShaderData *shaderData, uint instanceIndex : SV_VulkanInstanceID)
{
    VSOutput output;
    float4 translate = shaderData->pos[instanceIndex];
    Camera cam = shaderData->cam;

    float3 fragPos = rotate(rotate(input.Pos * translate.w, shaderData->quat) + translate.xyz - cam.pos.xyz, conj(cam.rot)) ;
    output.Normal = rotate(input.Normal, qmul(conj(cam.rot), shaderData->quat));
    output.LightVec = rotate(shaderData->lightPos.xyz - cam.pos.xyz, conj(cam.rot)) - fragPos;

    output.Pos = mul(shaderData->projection, float4(fragPos, 1.0));
    output.ViewVec  = -fragPos;

    output.instanceIndex = instanceIndex;
    output.UV = input.uv;
    output.factor = (shaderData->selected == instanceIndex? 3.0f : 1.0f);
    return output;
}

[shader("fragment")]
float4 main(VSOutput input)
{
    float3 N = normalize(input.Normal);
    float3 L = normalize(input.LightVec);
    float3 V = normalize(input.ViewVec);
    float3 R = reflect(-L, N);
    float3 diffuse = max(dot(N, L), 0.0025);
    float3 specular = pow(max(dot(R, V), 0.00001), 64.0) * 0.75;


    float3 color = textures[NonUniformResourceIndex(input.instanceIndex)].Sample(input.UV).rgb * input.factor;
    return float4(color.rgb * (diffuse + float3(0.1)) + specular, 1.0);
    // return float4(N, 1.0);
}

