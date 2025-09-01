// shader.metal

#include <metal_stdlib>
using namespace metal;

// MARK: - 変更点 (Swift側のVertex構造体と一致させる)
struct Vertex {
    float4 position;
    float4 color;
    float2 texCoord; // 法線の代わりにtexCoordを受け取る
};

struct Uniforms {
    float4x4 mvpMatrix;
};

// MARK: - 変更点 (フラグメントシェーダーに渡すデータ)
struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 texCoord; // texCoordをフラグメントシェーダーへ
};

vertex VertexOut vertex_main(const device Vertex* vertices [[buffer(0)]],
                             const device Uniforms& uniforms [[buffer(1)]],
                             uint vertexID [[vertex_id]]) {
    VertexOut out;
    
    out.position = uniforms.mvpMatrix * vertices[vertexID].position;
    out.color = vertices[vertexID].color;
    out.texCoord = vertices[vertexID].texCoord; // texCoordをそのまま渡す

    return out;
}

// MARK: - 変更点 (ライティングを廃止し、円形パーティクルを描画)
fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    // 1. texCoordからパーティクルの中心からの距離を計算
    // length()はベクトルの長さを計算する関数。中心(0,0)からの距離になる。
    float dist = length(in.texCoord); // 距離は 0.0 ~ 0.5 の範囲になる
    
    // 2. 距離を使って透明度(alpha)を計算
    // smoothstep(edge0, edge1, x)は、xがedge0以下のとき0, edge1以上のとき1を返し、
    // その間は滑らかに補間する関数。
    // これにより、中心(dist=0.0)では完全に不透明で、縁(dist=0.5)に近づくにつれて
    // 急速に透明になる、ソフトな円が描ける。
    float alpha = 1.0 - smoothstep(0.0, 0.5, dist);
    
    // 3. 元の色情報に、計算した透明度を適用して最終的な色を返す
    return float4(in.color.rgb, in.color.a * alpha);
}
