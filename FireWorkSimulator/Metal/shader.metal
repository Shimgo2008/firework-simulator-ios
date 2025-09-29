// shader.metal

#include <metal_stdlib>
using namespace metal;

// MARK: Swift側のVertex構造体と同じ
struct Vertex {
    float4 position;
    float4 color;
    float2 texCoord;
};

struct Uniforms {
    float4x4 mvpMatrix;
    float time;
};

struct ParticleInstance {
    float4x4 modelMatrix;
    float4 color;
};

// MARK: フラグメントシェーダーに渡すデータ
struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 texCoord; // texCoordをフラグメントシェーダーへ
    float time; // Time for animation effects
};

vertex VertexOut vertex_main(const device Vertex* vertices [[buffer(0)]],
                             const device ParticleInstance* instances [[buffer(1)]],
                             const device Uniforms& uniforms [[buffer(2)]],
                             uint vertexID [[vertex_id]],
                             uint instanceID [[instance_id]]) {
    VertexOut out;
    
    out.position = uniforms.mvpMatrix * instances[instanceID].modelMatrix * vertices[vertexID].position;
    out.color = instances[instanceID].color;
    out.texCoord = vertices[vertexID].texCoord; // texCoordをそのまま渡す
    out.time = uniforms.time; // Pass time to fragment shader

    return out;
}

// MARK: - 変更点 円形パーティクルを描画 with Gen Z sparkle ✨
fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    // 1. texCoordからパーティクルの中心からの距離を計算
    // 距離は 0.0 ~ 0.5 の範囲に正規化
    float dist = length(in.texCoord); 
    
    // 2. Gen Z sparkle effect: Add subtle shimmer animation using time
    float shimmer = sin(dist * 15.0 + in.time * 3.0) * 0.15 + 0.85;
    
    // 3. 距離を使って透明度(alpha)を計算 smoothstepを使うことにより、中心(dist=0.0)では完全に不透明で、縁(dist=0.5)では完全に透明になるようにする
    float alpha = (1.0 - smoothstep(0.0, 0.5, dist)) * shimmer;
    
    // 4. Add glow effect for that sparkle ✨
    float glow = 1.0 - smoothstep(0.3, 0.5, dist);
    float3 glowColor = in.color.rgb * 0.3 * glow;
    
    // 5. 元の色情報に、計算した透明度を適用して最終的な色を返す
    float3 finalColor = in.color.rgb + glowColor;
    return float4(finalColor, in.color.a * alpha);
}
