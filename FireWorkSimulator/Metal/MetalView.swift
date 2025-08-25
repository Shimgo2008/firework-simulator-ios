//
//  MetalView.swift
//  metalbenkyo-ios
//
//  Created by 岩澤慎平 on 2025/08/17.
//

import SwiftUI
import MetalKit

/// SwiftUIからMetalKitのMTKViewを利用するためのラッパービュー。
struct MetalView: UIViewRepresentable {
    
    @ObservedObject var viewModel: MetalViewModel

    /// `UIViewRepresentable`に必要なCoordinatorを生成する。
    func makeCoordinator() -> MetalCoordinator {
        // Metalのロジックを担当するCoordinatorを初期化
        MetalCoordinator(viewModel: viewModel)
    }
    
    /// SwiftUIがビューを最初に構築するときに一度だけ呼ばれ、MTKViewを生成する。
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        // デバイスの取得
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        mtkView.device = device
        
        // 基本設定
        mtkView.delegate = context.coordinator // 描画処理をCoordinatorに委任
        mtkView.isOpaque = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.depthStencilPixelFormat = .depth32Float
        
        // 描画タイミングの最適化：
        // `setNeedsDisplay()`が呼ばれたときだけ描画するように設定し、CPU/GPUの負荷を軽減
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = true
        
        
        // CoordinatorがMTKViewにアクセスできるように参照を渡す
        context.coordinator.parentView = mtkView
        
        return mtkView
    }
    
    /// SwiftUI側の状態が変化してビューが更新されるときに呼ばれる。（今回は使用しない）
    func updateUIView(_ uiView: MTKView, context: Context) {}
}
