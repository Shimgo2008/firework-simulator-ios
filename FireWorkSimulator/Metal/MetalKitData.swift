//
//  MetalKitData.swift
//  metalbenkyo-ios
//
//  Created by 岩澤慎平 on 2025/08/19.
//

import simd
import Foundation // sin, cosなどの数学関数を利用するため

// MARK: - Data Structures

/// GPUに送る頂点データの構造。シェーダー側の`Vertex`と一致させる必要がある。
struct Vertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>
    var normal: SIMD3<Float>
}

/// GPUに送るユニフォームデータの構造。シェーダー側の`Uniforms`と一致させる。
struct Uniforms {
    var mvpMatrix: simd_float4x4
}

/// 描画する直方体オブジェクトのプロパティを保持する構造体。
struct Cuboid {
    // オブジェクトの状態
    var position: SIMD3<Float>
    var rotation: SIMD3<Float>
    var dimensions: SIMD3<Float> // (width, height, depth)
    var color: SIMD4<Float>
    
    // アニメーション用の寿命
    var lifetime: Float
    
    /// このオブジェクトのトランスフォーム（スケール、回転、平行移動）を反映したモデル行列を計算して返す。
    func modelMatrix() -> simd_float4x4 {
        // 1. スケーリング行列
        let scalingMatrix = simd_float4x4(
            SIMD4<Float>(dimensions.x, 0, 0, 0),
            SIMD4<Float>(0, dimensions.y, 0, 0),
            SIMD4<Float>(0, 0, dimensions.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        
        // 2. 回転行列
        let rotX = rotation.x, rotY = rotation.y, rotZ = rotation.z
        let rotationXMatrix = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, cos(rotX), sin(rotX), 0),
            SIMD4<Float>(0, -sin(rotX), cos(rotX), 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        let rotationYMatrix = simd_float4x4(
            SIMD4<Float>(cos(rotY), 0, -sin(rotY), 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(sin(rotY), 0, cos(rotY), 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        let rotationZMatrix = simd_float4x4(
            SIMD4<Float>(cos(rotZ), sin(rotZ), 0, 0),
            SIMD4<Float>(-sin(rotZ), cos(rotZ), 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        
        // 3. 平行移動行列
        let translationMatrix = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(position.x, position.y, position.z, 1)
        )
        
        // 行列を結合: スケール -> 回転 -> 移動 の順で乗算する
        return translationMatrix * rotationZMatrix * rotationYMatrix * rotationXMatrix * scalingMatrix
    }
}


// MARK: - Helper Functions

/// 3D空間に遠近感を与えるための射影行列（Perspective Projection Matrix）を生成する。
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

/// カメラの位置と向きを定義するためのビュー行列（View Matrix）を生成する。
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

/// 指定されたCuboidオブジェクトから、原点中心の頂点データを生成する。
func makeCuboidVertices(from cuboid: Cuboid) -> [Vertex] {
    print("makeCuboidVertices")
    let hx: Float = 0.5, hy: Float = 0.5, hz: Float = 0.5
    
    let v000 = SIMD4<Float>(-hx, -hy, -hz, 1), v001 = SIMD4<Float>(-hx, -hy,  hz, 1)
    let v010 = SIMD4<Float>(-hx,  hy, -hz, 1), v011 = SIMD4<Float>(-hx,  hy,  hz, 1)
    let v100 = SIMD4<Float>( hx, -hy, -hz, 1), v101 = SIMD4<Float>( hx, -hy,  hz, 1)
    let v110 = SIMD4<Float>( hx,  hy, -hz, 1), v111 = SIMD4<Float>( hx,  hy,  hz, 1)
    
    let color = cuboid.color
    
    // MARK: - 各面の法線を定義
    let frontNormal = SIMD3<Float>(0, 0, 1), backNormal = SIMD3<Float>(0, 0, -1)
    let leftNormal  = SIMD3<Float>(-1, 0, 0), rightNormal = SIMD3<Float>(1, 0, 0)
    let topNormal   = SIMD3<Float>(0, 1, 0), bottomNormal = SIMD3<Float>(0, -1, 0)
    
    // MARK: - Vertexに法線情報を追加
    return [
        // 前面
        Vertex(position: v101, color: color, normal: frontNormal), Vertex(position: v001, color: color, normal: frontNormal), Vertex(position: v011, color: color, normal: frontNormal),
        Vertex(position: v101, color: color, normal: frontNormal), Vertex(position: v011, color: color, normal: frontNormal), Vertex(position: v111, color: color, normal: frontNormal),
        // 背面
        Vertex(position: v100, color: color, normal: backNormal), Vertex(position: v110, color: color, normal: backNormal), Vertex(position: v010, color: color, normal: backNormal),
        Vertex(position: v100, color: color, normal: backNormal), Vertex(position: v010, color: color, normal: backNormal), Vertex(position: v000, color: color, normal: backNormal),
        // 左面
        Vertex(position: v000, color: color, normal: leftNormal), Vertex(position: v010, color: color, normal: leftNormal), Vertex(position: v011, color: color, normal: leftNormal),
        Vertex(position: v000, color: color, normal: leftNormal), Vertex(position: v011, color: color, normal: leftNormal), Vertex(position: v001, color: color, normal: leftNormal),
        // 右面
        Vertex(position: v100, color: color, normal: rightNormal), Vertex(position: v101, color: color, normal: rightNormal), Vertex(position: v111, color: color, normal: rightNormal),
        Vertex(position: v100, color: color, normal: rightNormal), Vertex(position: v111, color: color, normal: rightNormal), Vertex(position: v110, color: color, normal: rightNormal),
        // 上面
        Vertex(position: v010, color: color, normal: topNormal), Vertex(position: v110, color: color, normal: topNormal), Vertex(position: v111, color: color, normal: topNormal),
        Vertex(position: v010, color: color, normal: topNormal), Vertex(position: v111, color: color, normal: topNormal), Vertex(position: v011, color: color, normal: topNormal),
        // 底面
        Vertex(position: v000, color: color, normal: bottomNormal), Vertex(position: v001, color: color, normal: bottomNormal), Vertex(position: v101, color: color, normal: bottomNormal),
        Vertex(position: v000, color: color, normal: bottomNormal), Vertex(position: v101, color: color, normal: bottomNormal), Vertex(position: v100, color: color, normal: bottomNormal)
    ]
}
