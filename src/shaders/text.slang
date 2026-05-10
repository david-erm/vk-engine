import desc;

struct Push {
    float2 cursorpos;
    uint image_index;
};

[shader("compute")]
[numthreads(12, 12, 1)]
void main(uint2 id : SV_DispatchThreadID, uniform Push push) {
    RWTexture2D swapchain = images[push.image_index];
    Texture2D bitmap = textures[4];  
    float4 color = bitmap.Load(int3((id / 4)% 96, 0));
    if (color.a > 0.1) {
        swapchain[id].rgb = float3(0.1, 0.0, 0.0);
    }

}
