//
//  MetalKitData.swift
//  FireWorkSimulator
//
//  Created by 岩澤慎平 on 2025/08/19.
//

import simd
import Foundation

// MARK: - Data Structures

struct Vertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>

    var texCoord: SIMD2<Float>
}

struct Uniforms {
    var mvpMatrix: simd_float4x4
}

struct Particle {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var color: SIMD4<Float>
    var size: Float
    var lifetime: Float
    
    // この粒子が上昇中の玉か、爆発後の星かを区別するのに使える
    enum ParticleType {
        case riser     // 上昇中の玉
        case star      // 爆発後の星
        case trail
    }
    var type: ParticleType
    
    // もし上昇中の玉(riser)なら、どの花火玉の情報を持っているか
    var shellPayload: FireworkShell2D? = nil
    
    var trailEmissionTimer: Float = .zero
}

struct ParticleInstance {
    var modelMatrix: simd_float4x4
    var color: SIMD4<Float>
}

// 頂点データを作る関数Particle用に変更
// makeParticleVertices関数も変更
func makeParticleVertices(size: Float) -> [Vertex] {
    let halfSize = size / 2.0
    
    // 各頂点にtexCoordを追加する
    let v0 = Vertex(position: .init(-halfSize, -halfSize, 0, 1), color: .init(1,1,1,1), texCoord: .init(-0.5, -0.5))
    let v1 = Vertex(position: .init( halfSize, -halfSize, 0, 1), color: .init(1,1,1,1), texCoord: .init( 0.5, -0.5))
    let v2 = Vertex(position: .init(-halfSize,  halfSize, 0, 1), color: .init(1,1,1,1), texCoord: .init(-0.5,  0.5))
    let v3 = Vertex(position: .init( halfSize,  halfSize, 0, 1), color: .init(1,1,1,1), texCoord: .init( 0.5,  0.5))
    
    // 2つの三角形で四角形を構成
    return [v0, v1, v2, v1, v3, v2]
}
// MARK: - Helper Functions

/// お勉強: https://qiita.com/ryutorion/items/0824a8d6f27564e850c9
/// 3D空間に遠近感を与えるための射影行列を生成する。
func makePerspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let yScale = 1 / tan(fovY * 0.5)
    let xScale = yScale / aspect
    let zRange = far - near
    let zScale = -(far + near) / zRange
    let wzScale = -2 * far * near / zRange
    
    return simd_float4x4(
        columns: (
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, wzScale, 0)
        )
    )
}

/// カメラの位置と向きを定義するためのビュー行列(View Matrix)を生成する。
func makeLookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let z = normalize(eye - center)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    let t = SIMD3<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye))
    
    return simd_float4x4(
        columns: (
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(t.x, t.y, t.z, 1)
        )
    )
}
