import "../structs";
import common;

#include "defines.slang"

struct VSOut {
  float4 pos : SV_Position; 
  uint32_t draw_id;
};

[shader("vertex")]
VSOut main(uniform Push push, uint32_t vid : SV_VulkanVertexID, uint32_t uid : SV_VulkanInstanceID) {
  Scene scene = push.scene[push.fif_index];
  Vertex v = push.vertices[vid];
  Pose pose = push.poses[uid];

  VSOut output;

  output.pos = mul(scene.projection, float4(scene.cam.toFrame(pose.transform(v.pos)), 1.0));
  output.draw_id = uid; 

  return output;
}

struct FSOut {
  uint32_t visbuffer : SV_Target0;
};

[shader("fragment")]
FSOut main(VSOut vsin, uint32_t prim_id : SV_PrimitiveID) {
  uint32_t visbuffer = (prim_id << DRAW_ID_BITS) | vsin.draw_id;
  return { visbuffer };
}
