RWTexture2D images[];


// static float3 colors[4] = {float3(0.1), float3(0.2), float3(0.3), float3(0.4)}; 

[shader("compute")]
[numthreads(16, 16, 1)]
void main(uint2 id : SV_DispatchThreadID, uniform uint image_index, uint3 wid : SV_GroupID) {
    RWTexture2D image = images[image_index];
    image[id].rgba = image[id].brga;
    // float3 fwid = wid;
    // float2 fid = id;
    // image[id].rgb = colors[(wid.x + wid.y) % 4];
}

