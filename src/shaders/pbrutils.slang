module pbrutils;

public static const float3 F0base = float3(0.04); 

public float3 fresnelSchlick(float cos_theta, float3 F0) {
  return F0 + (1.0 - F0) * pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0);
}

public float distributionGGX(float3 N, float3 H, float roughness) {
  const float a = roughness * roughness;
  const float a2 = a * a;
  const float NdotH = max(dot(N, H), 0.0);
  const float NdotH2 = NdotH * NdotH;

  float denom = (NdotH2 * (a2 - 1.0) + 1.0);
  denom = float.getPi() * denom * denom;  

  return a2 / denom;
}

public float geometryShlickGGX(const float NdotV, const float roughness) {
  const float r = (roughness + 1.0);
  const float k = (r*r) / 8.0;

  const float nom = NdotV;
  const float denom = NdotV * (1.0 - k) + k;

  return nom / denom;
}

public float geometrySmith(const float NdotV, const float NdotL, const float roughness) {
  const float ggx1 = geometryShlickGGX(NdotV, roughness);
  const float ggx2 = geometryShlickGGX(NdotL, roughness);

  return ggx1 * ggx2;
}

public float3 PBRNeutralToneMapping(float3 color) {
  const float start_compression = 0.8 - 0.04;
  const float desaturation = 0.15;

  float x = min(color.r, min(color.g, color.b));
  const float offset = x < 0.08 ? x  - 6.25 * x * x : 0.04;
  x -= offset;
  const float peak = max(color.r, max(color.g, color.b));
  if (peak  < start_compression) return color;

  const float d = 1. - start_compression;
  const float new_peak =  1. - d * d / (peak + d  - start_compression);
  color *= new_peak / peak;

  const float g = 1. - 1. / (desaturation * (peak - new_peak) + 1.);
  return lerp(color, new_peak * float3(1), g); 
}
