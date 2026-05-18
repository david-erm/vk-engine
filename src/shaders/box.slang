import desc;

struct Push {
    float2 cursorpos;
    uint image_index;
};

[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint2 id : SV_DispatchThreadID, uniform Push push) {
    RWTexture2D image = images[push.image_index];
    // float3 fwid = wid;
    // float2 fid = id;
    // float2 pos = float2(push.cursorpos);
    
    // if (10 > distance(pos, fid)) {    
        // image[id].rgb = float3(0.1, 0.3, 0.0);
    // } else {
        image[id].rgb = image[id].bgr;
    // }
    // image[id].rgb = colors[(wid.x + wid.y) % 4];
}

