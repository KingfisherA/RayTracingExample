#pragma once
#include <simd/simd.h>

namespace Ray {
    struct VertexData {
    simd::float4 position;
    simd::float2 texCoord;
    };
} // namespace Ray