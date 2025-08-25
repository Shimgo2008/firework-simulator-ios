//
//  MetalViewModel.swift
//  metalbenkyo-ios
//
//  Created by 岩澤慎平 on 2025/08/18.
//

import Combine
import CoreGraphics
import simd

class MetalViewModel: ObservableObject {
    let touchSubject = PassthroughSubject<SIMD3<Float>, Never>()
    
    // MARK: - 追加点
    // ARKitのカメラ情報を格納するプロパティ
    @Published var viewMatrix: simd_float4x4 = matrix_identity_float4x4
    @Published var projectionMatrix: simd_float4x4 = matrix_identity_float4x4
}
