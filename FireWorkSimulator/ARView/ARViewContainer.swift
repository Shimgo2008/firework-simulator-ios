// ARViewContainer.swift

import SwiftUI
import ARKit
import RealityKit
import simd

struct ARViewContainer: UIViewRepresentable {
    @Binding var arViewRef: ARView?
    var viewModel: MetalViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // ARViewの環境設定を最適化
        arView.environment.sceneUnderstanding.options = [.occlusion, .physics]
        
        
        // ARWorldTrackingConfigurationの詳細設定
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true
        
        // frameSemanticsの設定（サポートされている場合のみ）
        var supportedSemantics: ARConfiguration.FrameSemantics = []
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            supportedSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            supportedSemantics.insert(.smoothedSceneDepth)
        }
        configuration.frameSemantics = supportedSemantics
        
        // セッションのデリゲートを設定（run前に設定）
        arView.session.delegate = context.coordinator
        
        // セッションを開始
        arView.session.run(configuration)
        
        // 非同期で参照を保存（UI更新のため）
        DispatchQueue.main.async {
            self.arViewRef = arView
        }
        
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    // Coordinator初期化時に自身を渡す
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARViewContainer
        
        init(parent: ARViewContainer) {
            self.parent = parent
        }

        // 毎フレーム呼ばれるデリゲートメソッド
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // ARカメラのビュー行列と射影行列を取得
            let viewMatrix = frame.camera.viewMatrix(for: .portrait)
            let projectionMatrix = frame.camera.projectionMatrix(for: .portrait, viewportSize: parent.arViewRef?.bounds.size ?? .zero, zNear: 0.1, zFar: 100)

            // ViewModelに最新の行列を送信
            DispatchQueue.main.async {
                self.parent.viewModel.viewMatrix = viewMatrix
                self.parent.viewModel.projectionMatrix = projectionMatrix
            }
        }
    }
}

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        let translation = columns.3
        return SIMD3<Float>(translation.x, translation.y, translation.z)
    }
}
