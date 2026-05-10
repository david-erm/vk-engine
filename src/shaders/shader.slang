import util;
import desc;

struct VSInput {
    float3 Pos;
    float3 Normal;
    float2 uv;
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


[shader("vertex")]
VSOutput main(VSInput input, uniform ShaderData *shaderData, uint instanceIndex : SV_VulkanInstanceID)
{
    VSOutput output;
    Pose pose = shaderData->poses[instanceIndex];
    Pose cam = shaderData->cam;

    float3 fragPos = rotate(rotate(input.Pos * pose.pos.w, pose.rot) + pose.pos.xyz - cam.pos.xyz, conj(cam.rot)) ;
    output.Normal = rotate(input.Normal, qmul(conj(cam.rot), pose.rot));
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

    float3 color;
    color = sampled[NonUniformResourceIndex(input.instanceIndex)].Sample(input.UV).rgb * input.factor;
    return float4(color.rgb * (diffuse + float3(0.1)) + specular, 1.0);
  
}

