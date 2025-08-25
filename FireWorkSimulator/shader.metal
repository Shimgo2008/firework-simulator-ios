//
//  shader.metal
//  metalbenkyo-ios
//
//  Created by 岩澤慎平 on 2025/08/17.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position;
    float4 color;
    float3 normal; // SwiftのSIMD3<Float>に対応
};

struct Uniforms {
    float4x4 mvpMatrix;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    // MARK: - 追加点
    float3 normal; // 法線をフラグメントシェーダーに渡す
};

vertex VertexOut vertex_main(const device Vertex* vertices [[buffer(0)]],
                             const device Uniforms& uniforms [[buffer(1)]],
                             uint vertexID [[vertex_id]]) {
    VertexOut out;
    
    out.position = uniforms.mvpMatrix * vertices[vertexID].position;
    out.color = vertices[vertexID].color;
    
    // MARK: - 追加点
    // モデル行列の影響も考慮すべきだが、今回は回転のみのため単純に渡す
    // (正確には(M^-1)^Tを法線に掛ける)
    out.normal = vertices[vertexID].normal;

    return out;
}

// MARK: - 変更点 (ライティング計算を追加)
fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    // 固定のライト方向を定義（右上奥からのライト）
    float3 lightDirection = normalize(float3(0.5, 1.0, 0.5));
    
    // 法線とライト方向の内積から光の強さを計算 (0未満は0にする)
    float diffuseFactor = max(0.0, dot(in.normal, lightDirection));
    
    // 環境光（全体を照らす最低限の光）
    float ambientFactor = 0.3;
    
    // 最終的な色を計算
    float3 finalColor = in.color.rgb * (ambientFactor + diffuseFactor * 0.7);
    
    return float4(finalColor, in.color.a);
}
