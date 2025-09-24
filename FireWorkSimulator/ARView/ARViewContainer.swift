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
        DispatchQueue.main.async {
            self.arViewRef = arView
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)

        // ARSessionのデリゲートをCoordinatorに設定
        arView.session.delegate = context.coordinator


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
