import desc;

struct Push {
    float2 cursorpos;
    uint image_index;
};

[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint2 id : SV_DispatchThreadID, uniform Push push ) {
    RWTexture2D image = images[push.image_index];

    float3 compare = float3(image[id].rgb > 0.0031308);
    float3 lower = image[id].rgb * 12.92;
    float3 higher = 1.055 * pow(image[id].rgb, 1/2.4) - 0.055;

    image[id] = float4(lerp(lower, higher, compare), 1.0);
}
