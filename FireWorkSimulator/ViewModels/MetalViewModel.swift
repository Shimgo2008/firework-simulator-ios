//
//  MetalViewModel.swift
//  FireWorkSimulator
//
//  Created by shimgo on 2025/08/18.
//

import Combine
import CoreGraphics
import simd

// MetalCoordinatorと連携するためのViewModel
class MetalViewModel: ObservableObject {
    let launchSubject = PassthroughSubject<(FireworkShell2D, SIMD3<Float>), Never>()
    
    @Published var viewMatrix: simd_float4x4 = matrix_identity_float4x4
    @Published var projectionMatrix: simd_float4x4 = matrix_identity_float4x4
}
