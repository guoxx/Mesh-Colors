#ifndef FORWARD_SHADING_CGINC
#define FORWARD_SHADING_CGINC

#include "UnityCG.cginc"
#include "MeshColors.cginc"

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

struct v2f
{
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
};


v2f vert(appdata v)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.uv = v.uv;
    return o;
}

float sRGBToLinear(float srgb)
{
    if (srgb <= 0.04045f)
    {
        return srgb * (1.0f / 12.92f);
    }
    else
    {
        return pow((srgb + 0.055f) * (1.0f / 1.055f), 2.4f);
    }
}

/** Returns a linear-space RGB version of an input RGB color in the ITU-R BT.709 color space
    \param sRGBColor sRGB input color
*/
float3 sRGBToLinear(float3 srgb)
{
    return float3(
        sRGBToLinear(srgb.x),
        sRGBToLinear(srgb.y),
        sRGBToLinear(srgb.z));
}

float4 frag(v2f vertexInput, uint primitiveIndex: SV_PrimitiveID, centroid float3 vBaryWeights: SV_Barycentrics) : SV_Target
{
    float4 col = MeshColors_Sample(primitiveIndex, vBaryWeights);
    col.xyz = sRGBToLinear(col.xyz);

    return col;
}

#endif // FORWARD_SHADING_CGINC