module common;

public struct BarycentricDeriv {
    public float3 lambda;
    public float3 ddx;
    public float3 ddy;  
};

public float3 InterpolateWithDeriv(BarycentricDeriv deriv, float v0, float v1, float v2) {
    const float3 v = float3(v0, v1, v2);
    float3 ret;
    ret.x = dot(v, deriv.lambda);
    ret.y = dot(v, deriv.ddx);
    ret.z = dot(v, deriv.ddy);
    return ret;
}

// https://filmicworlds.com/blog/visibility-buffer-rendering-with-material-graphs/
public BarycentricDeriv CalcFullBary(float4 pt0, float4 pt1, float4 pt2, float2 pixel_ndc, float2 win_size) {
    BarycentricDeriv ret = (BarycentricDeriv)0;

    const float3 invW = rcp(float3(pt0.w, pt1.w, pt2.w));

    const float2 ndc0 = pt0.xy * invW.x;
    const float2 ndc1 = pt1.xy * invW.y;
    const float2 ndc2 = pt2.xy * invW.z;

    const float invDet = rcp(determinant(float2x2(ndc2 - ndc1, ndc0 - ndc1)));
    ret.ddx = float3(ndc1.y - ndc2.y, ndc2.y - ndc0.y, ndc0.y - ndc1.y) * invDet * invW;
    ret.ddy = float3(ndc2.x - ndc1.x, ndc0.x - ndc2.x, ndc1.x - ndc0.x) * invDet * invW;

    float ddx_sum = dot(ret.ddx, float3(1));
    float ddy_sum = dot(ret.ddy, float3(1));
    
    const float2 delta_vec = pixel_ndc - ndc0;
    const float interp_invw = invW.x + delta_vec.x*ddx_sum + delta_vec.y*ddy_sum;
    const float interpW = rcp(interp_invw);

    ret.lambda.x = interpW * (invW[0] + delta_vec.x*ret.ddx.x + delta_vec.y*ret.ddy.x);
    ret.lambda.y = interpW * (0.0f    + delta_vec.x*ret.ddx.y + delta_vec.y*ret.ddy.y);
    ret.lambda.z = interpW * (0.0f    + delta_vec.x*ret.ddx.z + delta_vec.y*ret.ddy.z);

    ret.ddx *= (2.0/win_size.x);
    ret.ddy *= (2.0/win_size.y);
    ddx_sum *= (2.0/win_size.x);
    ddy_sum *= (2.0/win_size.y);

    //We are on vulkan, so y is flipped. Leaving this here for sanity
    // ret.ddy *= -1.0;
    // ddy_sum *= -1.0;

    const float interW_ddx = 1.0 / (interp_invw + ddx_sum);
    const float interW_ddy = 1.0 / (interp_invw + ddy_sum);

    ret.ddx = interW_ddx*(ret.lambda*interp_invw + ret.ddx) - ret.lambda;
    ret.ddy = interW_ddy*(ret.lambda*interp_invw + ret.ddy) - ret.lambda;

    return ret;
}
