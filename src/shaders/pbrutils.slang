module pbrutils;

public float3 fresnelSchlick(float cos_theta, float3 F0) {
  return F0 + (1.0 - F0) * pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0);
}

public float DistributionGGX(float3 N, float3 H, float roughness) {
  const float a = roughness * roughness;
  const float a2 = a * a;
  const float NdotH = max(dot(N, H), 0.0);
  const float NdotH2 = NdotH * NdotH;
}
