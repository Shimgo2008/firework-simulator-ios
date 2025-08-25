import SwiftUI
import RealityKit
import ARKit

// MARK: - Haptic Feedback Manager
/// ハプティックフィードバック（振動）を管理するシンプルなヘルパー
struct HapticManager {
    static let shared = HapticManager()
    private let generator = UIImpactFeedbackGenerator(style: .medium)
    private init() {} // Singleton

    /// 中程度の強さの振動を発生させる
    func impact() {
        generator.impactOccurred()
    }
}


// MARK: - Camera Mode Definition
enum CameraMode: String, CaseIterable, Identifiable {
    case photo = "写真"
    case video = "ビデオ"
    // 将来的に「スロー」「タイムラプス」などを追加可能
    
    var id: String { self.rawValue }
}


struct ARViewScreen: View {
    // ViewModelとAR体験の管理クラス
    @StateObject private var shellViewModel = ShellViewModel()
    private let arManager = ARManager()
    
    // UIの状態管理
    @State private var isShowingShellListView = false
    @State private var isRecording = false
    @State private var selectedMode: CameraMode = .photo
    
    // --- ジェスチャーとUI計算用の状態変数 ---
    @GestureState private var dragOffset: CGFloat = 0
    @State private var currentOffset: CGFloat = 0

    // 設定値
    private let fireworkDistance: Float = 30.0

    var body: some View {
        NavigationView {
            ZStack {
               ARViewContainer(shellViewModel: shellViewModel,
                               arManager: arManager,
                               fireworkDistance: fireworkDistance)
                   .edgesIgnoringSafeArea(.all)

                VStack {
                    topBar
                    Spacer()
                    bottomControlArea
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $isShowingShellListView) {
            ShellListView()
        }
    }

    // MARK: - UI Components

    private var topBar: some View {
        HStack {
            Button(action: {}) { Image(systemName: "gear") }
            Spacer()
            Button(action: {}) { Image(systemName: "bolt.slash.fill") }
        }
        .font(.title2)
        .padding()
        .foregroundColor(.white)
        .background(Color.black.opacity(0.3))
    }
    
    private var bottomControlArea: some View {
        VStack(spacing: 20) {
            modeSelector
            controlButtons
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.3))
    }

    private var modeSelector: some View {
        // 各アイテムの幅と間隔を定義
        let itemWidth: CGFloat = 80
        let spacing: CGFloat = 1

        let centeringCorrection = (CGFloat(CameraMode.allCases.count - 1) * (itemWidth + spacing)) / 2.0

        // ドラッグジェスチャーの定義
        let dragGesture = DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                currentOffset += value.translation.width
                
                let itemTotalWidth = itemWidth + spacing
                let targetIndex = max(0, min(CGFloat(CameraMode.allCases.count - 1), round(-currentOffset / itemTotalWidth)))
                
                let newOffset = -itemTotalWidth * targetIndex
                let newMode = CameraMode.allCases[Int(targetIndex)]
                
                if newMode != selectedMode {
                    HapticManager.shared.impact()
                }
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    currentOffset = newOffset
                    selectedMode = newMode
                }
            }
        
        return ZStack {
            Capsule()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: itemWidth, height: 30)

            HStack(spacing: spacing) {
                ForEach(CameraMode.allCases) { mode in
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .scaleEffect(selectedMode == mode ? 1.1 : 1.0)
                        .foregroundColor(selectedMode == mode ? .yellow : .white)
                        .frame(width: itemWidth)
                }
            }
            .offset(x: centeringCorrection + currentOffset + dragOffset)
            .gesture(dragGesture)
        }
        .mask(Capsule().frame(height: 50))
    }

    private var controlButtons: some View {
        HStack(alignment: .center, spacing: 20) {
            shellListButton
            Spacer()
            Group {
                switch selectedMode {
                case .photo:
                    photoShutterButton
                case .video:
                    videoRecordButton
                }
            }
            .id(selectedMode) // モード切り替え時にボタンが再描画されるようにIDを設定
            .transition(.opacity.combined(with: .scale(scale: 0.8))) // <<<--- ボタンの切り替えアニメーション
            Spacer()
            Rectangle()
                .fill(Color.clear)
                .frame(width: 50, height: 50)
        }
        .padding(.horizontal, 30)
    }

    private var shellListButton: some View {
        Button(action: { isShowingShellListView = true }) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
                .background(Color.black.opacity(0.5))
                .overlay(Image(systemName: "sparkles").foregroundColor(.white).font(.title2))
        }
        .frame(width: 50, height: 50)
    }
    
    private var photoShutterButton: some View {
        Button(action: {
            HapticManager.shared.impact()
            print("📸 写真を撮影しました！")
        }) {
            ZStack {
                Circle().stroke(Color.white, lineWidth: 4)
                Circle().fill(Color.white).padding(6)
            }
        }
        .frame(width: 70, height: 70)
    }

    private var videoRecordButton: some View {
        Button(action: {
            HapticManager.shared.impact()
            withAnimation(.spring()) { isRecording.toggle() }
            
            if isRecording { print("🔴 録画開始") } else { print("⏹️ 録画停止") }
        }) {
            ZStack {
                Circle().stroke(Color.white, lineWidth: 4)
                
                if isRecording {
                    RoundedRectangle(cornerRadius: 4).fill(Color.red).frame(width: 25, height: 25)
                } else {
                    Circle().fill(Color.red).frame(width: 58, height: 58)
                }
            }
        }
        .frame(width: 70, height: 70)
    }
}

// PreferenceKey for scroll offset detection
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - ARViewContainer & Coordinator (変更なし)
struct ARViewContainer: UIViewRepresentable {
    let shellViewModel: ShellViewModel
    let arManager: ARManager
    let fireworkDistance: Float

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        
        arManager.setup(with: arView)
        context.coordinator.arManager = arManager
        context.coordinator.shellViewModel = shellViewModel
        
        // 画面タップで花火を打ち上げるジェスチャー
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.fireworkDistance = fireworkDistance
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var arManager: ARManager?
        var shellViewModel: ShellViewModel?
        var fireworkDistance: Float = 30.0

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = sender.view as? ARView else { return }
            
            let cameraTransform = arView.cameraTransform
            let cameraForward = SIMD3<Float>(-cameraTransform.matrix.columns.2.x, -cameraTransform.matrix.columns.2.y, -cameraTransform.matrix.columns.2.z)
            let fireworkPosition = cameraTransform.translation + cameraForward * fireworkDistance
            
            if let randomShell = shellViewModel?.shells.randomElement() {
                arManager?.launchFirework(shell: randomShell, at: fireworkPosition)
            } else {
                arManager?.launchDefaultFirework(at: fireworkPosition)
            }
        }
    }
}


// MARK: - Preview
struct ARViewScreen_Previews: PreviewProvider {
    static var previews: some View {
        ARViewScreen()
    }
}
