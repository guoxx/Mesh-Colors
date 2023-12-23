#ifndef MESH_COLORS_CGINC
#define MESH_COLORS_CGINC

// UNITY_SHADER_NO_UPGRADE

StructuredBuffer<uint> _MeshColors_PatchBuffer;
StructuredBuffer<uint2> _MeshColors_MetaBuffer;
ByteAddressBuffer _MeshColors_AdjacencyInfoBuffer;

struct MeshColors_MetaInfo
{
    uint address;
    uint resolution;
};

struct MeshColors_AdjacencyInfo
{
    uint3 TriangleIndices;
    uint3 LocalEdgeIndices;
};

MeshColors_MetaInfo MeshColors_LoadMetaInfo(uint primitiveIndex)
{
    MeshColors_MetaInfo metaInfo;
    metaInfo.address = _MeshColors_MetaBuffer[primitiveIndex].x;
    metaInfo.resolution = _MeshColors_MetaBuffer[primitiveIndex].y;
    return metaInfo;
}

MeshColors_AdjacencyInfo MeshColors_LoadAdjacencyInfo(uint primitiveIndex)
{
    MeshColors_AdjacencyInfo adjacencyInfo;
    adjacencyInfo.TriangleIndices = _MeshColors_AdjacencyInfoBuffer.Load3(primitiveIndex * 24);
    adjacencyInfo.LocalEdgeIndices = _MeshColors_AdjacencyInfoBuffer.Load3(primitiveIndex * 24 + 12);
    return adjacencyInfo;
}

uint3 MeshColors_B(float3 bary, uint resolution)
{
    return (uint3)((float)resolution * bary);
}

float3 MeshColors_W(float3 bary, uint resolution)
{
    return (float)resolution * bary - MeshColors_B(bary, resolution);
}

float MeshColors_UnpackR8ToUFLOAT(uint r)
{
    const uint mask = (1U << 8) - 1U;
    return (float)(r & mask) / (float)mask;
}

float4 MeshColors_UnpackR8G8B8A8ToUFLOAT(uint rgba)
{
    float r = MeshColors_UnpackR8ToUFLOAT(rgba);
    float g = MeshColors_UnpackR8ToUFLOAT(rgba >> 8);
    float b = MeshColors_UnpackR8ToUFLOAT(rgba >> 16);
    float a = MeshColors_UnpackR8ToUFLOAT(rgba >> 24);
    return float4(r, g, b, a);
}

float4 MeshColors_C(uint i, uint j, uint resolution, uint baseAddress)
{
    uint offset = i * ((resolution + 1) + (resolution + 2 - i)) / 2;
    uint address = baseAddress + offset + j;
    return MeshColors_UnpackR8G8B8A8ToUFLOAT(_MeshColors_PatchBuffer[address]);
}

float4 MeshColors_Sample(uint primitiveIndex, float3 bary)
{
    MeshColors_MetaInfo metaInfo = MeshColors_LoadMetaInfo(primitiveIndex);

    uint2 ij = MeshColors_B(bary, metaInfo.resolution).xy;
    uint i = ij.x;
    uint j = ij.y;

    float4 col;
#if 1 // Bilinear
    float3 weight = MeshColors_W(bary, metaInfo.resolution);
    if (weight.x + weight.y + weight.z > 1.9f)
    {
        weight = 1.0f - weight;
        col = weight.x * MeshColors_C(i, j + 1, metaInfo.resolution, metaInfo.address)
        + weight.y * MeshColors_C(i + 1, j, metaInfo.resolution, metaInfo.address)
        + weight.z * MeshColors_C(i + 1, j + 1, metaInfo.resolution, metaInfo.address);
    }
    else
    {
        col = weight.x * MeshColors_C(i + 1, j, metaInfo.resolution, metaInfo.address) 
        + weight.y * MeshColors_C(i, j + 1, metaInfo.resolution, metaInfo.address)
        + weight.z * MeshColors_C(i, j, metaInfo.resolution, metaInfo.address);
    }
#else
    col = MeshColors_C(i, j, metaInfo.resolution, metaInfo.address);
#endif

    return col;
}

float2x3 MeshColors_AdjacencyTransformMatrix(uint srcEdge, uint dstEdge, bool sameWindingOrder)
{
    float2x3 m = 0;
    if (srcEdge == 0)
    {
        if (dstEdge == 0)
        {
            if (sameWindingOrder)
            {
                m =  ((-1, 0, 1), (0, -1, 0));
            }
            else
            {
                m = ((1, 0, 0), (0, -1, 0));
            }
        }
        else if (dstEdge == 1)
        {
            if (sameWindingOrder)
            {
                m = ((0, -1, 0), (1, 0, 0));
            }
            else
            {
                m = ((0, -1, 0), (-1, 0, 1));
            }
        }
        else
        {
            if (sameWindingOrder)
            {
                m = ((0.5, 0.5, 0.5), (-0.5, 0.5, -0.5));
            }
            else
            {
                m = ((-0.5, 0.5, 0.5), (0.5, 0.5, -0.5));
            }
        }
    }
    else if (srcEdge == 1)
    {
        if (dstEdge == 0)
        {
            if (sameWindingOrder)
            {
                m = ((0, 1, 0), (0, -1, 0));
            }
            else
            {
                m = ((0, -1, 1), (0, -1, 1));
            }
        }
        else if (dstEdge == 1)
        {
            if (sameWindingOrder)
            {
                m = ((-1, 0, 0), (0, -1, 1));
            }
            else
            {
                m = ((-1, 0, 0), (0, 1, 0));
            }
        }
        else
        {
            if (sameWindingOrder)
            {
                m = ((0.5, -0.5, -0.5), (0.5, 0.5, 0.5));
            }
            else
            {
                m = ((0.5, 0.5, -0.5), (0.5, -0.5, 0.5));
            }
        }
    }
    else
    {
        if (dstEdge == 0)
        {
            if (sameWindingOrder)
            {
                m = ((1, -1, 0), (1, 1, 1));
            }
            else
            {
                m = ((-1, 1, 1), (1, 1, 0));
            }
        }
        else if (dstEdge == 1)
        {
            if (sameWindingOrder)
            {
                m = ((1, 1, 1), (-1, 1, 0));
            }
            else
            {
                m = ((1, 1, 0), (-1, 1, 1));
            }
        }
        else
        {
            if (sameWindingOrder)
            {
                m = ((-1, 0, 1), (0, -1, 1));
            }
            else
            {
                m = ((0, -1, 1), (-1, 0, 1));
            }
        }
    }
    return m;
}

float4 MeshColors_SampleAcrossTriangles(uint primitiveIndex, float2 origin, float2 dir, float t)
{
    float4 color = 0;

    for (uint iter = 0; iter < 8; iter++)
    {
        // intersect with the nearest boundary
        // 0: y = 0
        float t0 = -origin.y / dir.y;
        // 1: x = 0
        float t1 = -origin.x / dir.x;
        // 2: x + y = 1
        float t2 = -(origin.x + origin.y) / (dir.x + dir.y);
        
        uint hitEdge = -1;
        float hitT = 1e10f;
        if (t0 > 0 && t0 < hitT)
        {
            hitEdge = 0;
            hitT = t0;
        }
        if (t1 > 0 && t1 < hitT)
        {
            hitEdge = 1;
            hitT = t1;
        }
        if (t2 > 0 && t2 < hitT)
        {
            hitEdge = 2;
            hitT = t2;
        }

        if (hitEdge == -1)
        {
            break;
        }

        // dist is smaller than the distance to the nearest neighbor, stop inside triangle
        if (t < hitT)
        {
            float2 target = origin + dir * t;
            color = MeshColors_Sample(primitiveIndex, float3(target, 1 - target.x - target.y));
            break;
        }

        // dist is bigger than the distance to the nearest neighbor, reduce the distance and move to the next triangle
        MeshColors_AdjacencyInfo adjacencyInfo = MeshColors_LoadAdjacencyInfo(primitiveIndex);

        uint nextPrimitiveIndex = adjacencyInfo.TriangleIndices[hitEdge];
        uint nextPrimitiveEdge = adjacencyInfo.LocalEdgeIndices[hitEdge];
        if (nextPrimitiveIndex == 0xffffffff || nextPrimitiveEdge == 0xffffffff)
        {
            break;
        }

        // TODO: check winding order
        bool sameWindingOrder = true;
        float2x3 transformMatrix = MeshColors_AdjacencyTransformMatrix(hitEdge, nextPrimitiveEdge, sameWindingOrder);

        origin = mul(transformMatrix, float3(origin + dir * hitT, 1)).xy;
        dir = mul(transformMatrix, float3(dir, 0)).xy;
        t -= hitT;
        primitiveIndex = nextPrimitiveIndex;
    }

    return color;
}

#endif // MESH_COLORS_CGINC