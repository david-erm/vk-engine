import desc;
import util;

struct VSOut {
    nointerpolation Material mat;  
    float4 Pos : SV_POSITION;
    float3 Normal;
    float2 UV;
    float3 factor;
    float3 LightVec;
    float3 ViewVec;
};

[shader("vertex")]
VSOut main(uniform Push push, uint vid : SV_VulkanVertexID, uint iid : SV_VulkanInstanceID) {
    VSOut output;
    Vertex v = push.vertices[vid];

    Pose pose = push.poses[iid];
    Pose cam = push.scene.cam;

    float3 fragPos = rotate(rotate(v.pos * pose.pos.w, pose.rot) + pose.pos.xyz - cam.pos.xyz, conj(cam.rot)) ;
    output.Normal = rotate(v.norm, qmul(conj(cam.rot), pose.rot));
    output.LightVec = rotate(push.scene.lightPos.xyz - cam.pos.xyz, conj(cam.rot)) - fragPos;

    output.Pos = mul(push.scene.projection, float4(fragPos, 1.0));
    output.ViewVec  = -fragPos;

    output.mat = push.materials[iid];
    output.UV = v.tex;
    
    return output;

};

[shader("fragment")]
float4 main(VSOut input) {
  
}
