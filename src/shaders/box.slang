RWTexture2D images[];

[shader("compute")]
[numthreads(8, 8)]
void main(uint2 id : SV_DispatchThreadID, uniform uint image_index) {
    // float3 color_accum = float3(0);
    // uint pixel_count = 0;
    // for (int i = -1; i < 2; i++) {
    //     for (int j = -1; j < 2; j++) {
    //         color_accum = image[uint2(id.x + i, id.y + j)].rgb;
    //         pixel_count++;
    //     }
    // }
    RWTexture2D image = images[image_index];
    float avg = (image[id].r + image[id].g + image[id].b) / 3;
    image[id].rgb = float3(avg);
    // images[image_index][id].rgb = images[image_index][id].rgb * images[image_index][id].rgb;
}

