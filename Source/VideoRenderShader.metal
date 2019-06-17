//
//  VideoRenderShader.metal
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/13.
//

#if __METAL_MACOS__ || __METAL_IOS__

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

constexpr sampler defaultSampler(coord::normalized, address::clamp_to_edge, filter::linear);

vertex VertexOut passthroughVertices(device packed_float2 *positions [[buffer(0)]],
                                     device packed_float2 *textureCoords [[buffer(1)]],
                                     uint vid [[vertex_id]])
{
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.texCoord = textureCoords[vid];
    return out;
}

fragment float4 renderTexture(VertexOut vertexParam [[stage_in]],
                       texture2d<float> texture [[texture(0)]])
{
    return texture.sample(defaultSampler, vertexParam.texCoord);
}
#endif



