import SwiftUI
import RealityKit
import ARKit

// --- ARViewScreen (SwiftUI View) ---
// このView自体の変更はほぼありません。
struct ARViewScreen: View {
    @StateObject private var shellViewModel = ShellViewModel()
    @State private var debugDistance: Float = 20.0
    @State private var isShowingShellListView = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ARViewContainer(shellViewModel: shellViewModel, debugDistance: $debugDistance)
                .edgesIgnoringSafeArea(.all)
            
            debugSlider
            
            floatingActionButton
        }
        .sheet(isPresented: $isShowingShellListView) {
            ShellListView() // ViewModelはShellListView内で初期化される想定
        }
    }
    
    // UIコンポーネントをプロパティとして分離
    private var debugSlider: some View {
        VStack {
            Spacer()
            VStack {
                Text("花火距離: \(String(format: "%.1f", debugDistance))m")
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                
                Slider(value: $debugDistance, in: 1...50, step: 0.5)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
    }
    
    private var floatingActionButton: some View {
        Button(action: {
            self.isShowingShellListView = true
        }) {
            Image(systemName: "plus")
                .font(.title.weight(.semibold))
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(radius: 4, x: 0, y: 4)
        }
        .padding(20)
    }
}

struct ARViewContainer: UIViewRepresentable {
    let shellViewModel: ShellViewModel
    @Binding var debugDistance: Float
    
    // ARManagerのインスタンスをここで生成・保持
    private let arManager = ARManager()
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        
        // ARManagerにARViewを渡してセットアップ
        arManager.setup(with: arView)
        
        // CoordinatorにARManagerとViewModelを渡す
        context.coordinator.arManager = arManager
        context.coordinator.shellViewModel = shellViewModel
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Coordinatorが持つデバッグ距離を更新
        context.coordinator.debugDistance = debugDistance
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // --- Coordinator (仲介者) ---
    // ロジックが大幅に削減され、イベントの翻訳に専念。
    class Coordinator: NSObject {
        var arManager: ARManager?
        var shellViewModel: ShellViewModel?
        var debugDistance: Float = 20.0

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = sender.view as? ARView else { return }

            // 1. タップ位置から3D空間の打ち上げ座標を計算する（ここまではCoordinatorの責務）
            print("たっちされた")
            let cameraTransform = arView.cameraTransform
            let cameraPosition = cameraTransform.translation
            let cameraForward = -normalize(SIMD3<Float>(cameraTransform.matrix.columns.2.x, cameraTransform.matrix.columns.2.y, cameraTransform.matrix.columns.2.z))
            let fireworkPosition = cameraPosition + (cameraForward * debugDistance)
            
            print("距離: \(fireworkPosition)")
            
            // 2. 打ち上げる花火データを決定する
            if let randomShell = shellViewModel?.shells.randomElement() {
                // 3. 計算した座標とデータをARManagerに渡して「打ち上げ」を依頼する
                arManager?.launchFirework(shell: randomShell, at: fireworkPosition)
            } else {
                arManager?.launchDefaultFirework(at: fireworkPosition)
            }
        }
    }
}
