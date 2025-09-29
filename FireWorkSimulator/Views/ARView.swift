import SwiftUI
import RealityKit
import ARKit
import ReplayKit

// MARK: - Haptic Feedback Manager
struct HapticManager {
    static let shared = HapticManager()
    private let generator = UIImpactFeedbackGenerator(style: .medium)
    private init() {} // Singleton

    func impact() {
        generator.impactOccurred()
    }
}


// MARK: - Camera Mode Definition
enum CameraMode: String, CaseIterable, Identifiable {
    case photo = "写真"
    case video = "ビデオ"
    
    var id: String { self.rawValue }
}


struct ARViewScreen: View {
    
    // UIの状態管理
    @State private var isShowingShellListView = false
    @State private var isRecording = false
    @State private var selectedMode: CameraMode = .photo
    @State private var previewViewController: RPPreviewViewController? = nil
    @State private var isShowingP2PRoomView = false

    // --- ジェスチャーとUI計算用の状態変数 ---
    @GestureState private var dragOffset: CGFloat = 0
    @State private var currentOffset: CGFloat = 0

    @StateObject private var viewModel = MetalViewModel()
    @State private var arViewRef: ARView? = nil

    // 花火玉リストの管理
    @StateObject private var shellListViewModel = ShellListViewModel()
    @State private var selectedShell: FireworkShell2D?

    // P2Pマネージャー
    @EnvironmentObject var p2pManager: P2PManager
    
    // Weather and sensory effects for Gen Z experience ✨
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var sensoryEffectsManager: SensoryEffectsManager

    // カメラキャプチャ管理
    private let cameraCapture = CameraCapture()
    // 画面録画管理
    private let screenRecorder = ScreenRecorder()

    private let fireworkDistance: Float = 30.0

    var body: some View {
        NavigationView {
            ZStack {
                GeometryReader { geometry in
                    ZStack {
                        ARViewContainer(arViewRef: $arViewRef, viewModel: viewModel)
                            .edgesIgnoringSafeArea(.all)
                        MetalView(
                            viewModel: viewModel,
                            sensoryEffectsManager: sensoryEffectsManager,
                            arViewRef: arViewRef
                        )
                        .edgesIgnoringSafeArea(.all)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard let arView = arViewRef, let shell = selectedShell else { return }
                                
                                if let result = arView.raycast(from: value.location, allowing: .estimatedPlane, alignment: .any).first {

                                    // 1. タップされたAR空間上の座標を取得
                                    let tappedPosition = result.worldTransform.translation
                                    
                                    // 2. 現在のカメラの位置を取得
                                    let cameraPosition = arView.cameraTransform.matrix.translation
                                    
                                    // 3. 花火を打ち上げるための最低距離を定義(例: 15メートル)
                                    let minLaunchDistance: Float = 15.0
                                    
                                    // 4. カメラからタップ地点までの距離を計算
                                    let vectorFromCamera = tappedPosition - cameraPosition
                                    let distance = length(vectorFromCamera)
                                    
                                    var finalLaunchPosition = tappedPosition
                                    
                                    // 5. 最低距離より近かった場合
                                    if distance < minLaunchDistance {
                                        // カメラからの方向ベクトルを計算
                                        let direction = normalize(vectorFromCamera)
                                        
                                        // カメラの位置から、最低距離だけ離れた新しい位置を計算
                                        let pushedBackPosition = cameraPosition + direction * minLaunchDistance
                                        
                                        // XとZ座標は新しい位置のものを採用し、
                                        // Y座標(高さ)は元のタップ地点(地面の高さ)を維持する
                                        finalLaunchPosition.x = pushedBackPosition.x
                                        finalLaunchPosition.z = pushedBackPosition.z
                                    }
                                    
                                    // 6. 最終的に決定した打ち上げ位置をViewModelに送信
                                    viewModel.launchSubject.send((shell, finalLaunchPosition))

                                    // P2P同期: 相対座標を計算して送信
                                    if p2pManager.isConnected, let origin = p2pManager.groupOrigin {
                                        let relativePosition = finalLaunchPosition - origin
                                        print("[AR] Sending P2P firework: relative \(relativePosition)")
                                        p2pManager.sendFireworkLaunch(shell: shell, relativePosition: relativePosition)
                                    }

                                }
                            }
                    )
                    .onReceive(p2pManager.fireworkLaunchSubject) { shell, relativePosition, timestamp in
                        // P2P受信: 相対座標を絶対座標に変換して発火
                        if let origin = p2pManager.groupOrigin {
                            let absolutePosition = origin + relativePosition
                            print("[AR] Received P2P firework: absolute \(absolutePosition)")
                            viewModel.launchSubject.send((shell, absolutePosition))
                        } else {
                            print("[AR] No group origin set, ignoring P2P firework")
                        }
                    }
                    .onChange(of: p2pManager.isConnected) { isConnected in
                        // 接続時に中点を設定
                        if isConnected, let arView = arViewRef {
                            let cameraPosition = arView.cameraTransform.matrix.translation
                            print("[AR] Setting group origin on connect: \(cameraPosition)")
                            p2pManager.setGroupOrigin(origin: cameraPosition)
                        }
                    }
                }
                VStack {
                    topBar
                    Spacer()
                    
                    // Wind indicator for that authentic weather vibe 🌪️
                    HStack {
                        Spacer()
                        windIndicator
                            .padding(.trailing)
                        Spacer()
                    }
                    
                    bottomControlArea
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $isShowingShellListView) {
            ShellListView(selectedShell: $selectedShell)
        }
        .sheet(isPresented: $isShowingP2PRoomView) {
            P2PRoomView()
                .environmentObject(p2pManager)
        }
        .onAppear {
            // Set default shell if none selected
            if selectedShell == nil && !shellListViewModel.shells.isEmpty {
                selectedShell = shellListViewModel.shells.first
            }
        }
    }


    // MARK: - UI Components

    private var topBar: some View {
        HStack {
            Button(action: { isShowingP2PRoomView = true }) { 
                Image(systemName: "person.3.fill") 
                    .foregroundColor(.white)
                    .font(.title2)
            }
            
            Spacer()
            
            // Weather info for that authentic Gen Z tech vibe 🌡️
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer")
                        .font(.caption)
                    Text("\(Int(weatherService.currentTemperature))°C")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                    Text("\(Int(weatherService.soundSpeed))m/s")
                        .font(.caption2)
                        .opacity(0.8)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            
            Spacer()
            
            Button(action: {}) { 
                Image(systemName: "bolt.slash.fill")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .font(.title2)
        .padding()
        .background(
            LinearGradient(
                colors: [.black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
        let itemWidth: CGFloat = 80
        let spacing: CGFloat = 1

        let centeringCorrection = (CGFloat(CameraMode.allCases.count - 1) * (itemWidth + spacing)) / 2.0

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
            // Enhanced background with gradient for Gen Z aesthetic ✨
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            .yellow.opacity(0.4),
                            .orange.opacity(0.3),
                            .pink.opacity(0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: itemWidth, height: 30)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )

            HStack(spacing: spacing) {
                ForEach(CameraMode.allCases) { mode in
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .scaleEffect(selectedMode == mode ? 1.1 : 1.0)
                        .foregroundColor(selectedMode == mode ? .white : .white.opacity(0.7))
                        .frame(width: itemWidth)
                        .shadow(
                            color: selectedMode == mode ? .yellow.opacity(0.5) : .clear,
                            radius: 4, x: 0, y: 0
                        )
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
            .id(selectedMode)
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            Spacer()
            Rectangle()
                .fill(Color.clear)
                .frame(width: 50, height: 50)
        }
        .padding(.horizontal, 30)
    }

    private var shellListButton: some View {
        Button(action: { isShowingShellListView = true }) {
            if let shell = selectedShell {
                FireworkPreview(shell: shell)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow, .orange, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .gray.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    
                    VStack(spacing: 2) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                        Text("花火")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .shadow(color: .yellow.opacity(0.3), radius: 2, x: 0, y: 0)
                }
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Wind Indicator for Gen Z Aesthetic
    
    private var windIndicator: some View {
        VStack(spacing: 4) {
            Image(systemName: "wind")
                .font(.caption)
                .foregroundColor(.white)
                .rotationEffect(.degrees(Double.random(in: -10...10))) // Subtle random rotation for dynamic feel
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
            
            Text("風")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .cyan.opacity(0.3), radius: 2, x: 0, y: 0)
    }
    
    private var photoShutterButton: some View {
        Button(action: {
            HapticManager.shared.impact()
            if let arView = arViewRef {
                cameraCapture.capturePhoto(from: arView)
            }
            print("📸 写真を撮影してカメラロールに保存しました！")
        }) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white, .gray.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(6)
                    .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
            }
        }
        .frame(width: 70, height: 70)
    }

    private var videoRecordButton: some View {
        Button(action: {
            HapticManager.shared.impact()
            withAnimation(.spring()) { isRecording.toggle() }
            if isRecording {
                screenRecorder.startRecording { error in
                    if let error = error {
                        print("[ScreenRecorder] 録画開始エラー: \(error.localizedDescription)")
                    } else {
                        print("[ScreenRecorder] 録画開始")
                    }
                }
            } else {
                screenRecorder.stopRecording { previewVC, error in
                    if let error = error {
                        print("[ScreenRecorder] 録画停止エラー: \(error.localizedDescription)")
                    } else if let previewVC = previewVC {
                        print("[ScreenRecorder] 録画完了: プレビュー画面を表示")
                        previewViewController = previewVC
                    } else {
                        print("[ScreenRecorder] 録画完了: プレビュー画面なし")
                    }
                }
            }
        }) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.red, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 25, height: 25)
                        .shadow(color: .red.opacity(0.6), radius: 4, x: 0, y: 0)
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .shadow(color: .red.opacity(0.4), radius: 2, x: 0, y: 0)
                }
            }
        }
        .frame(width: 70, height: 70)
        .scaleEffect(isRecording ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FireworkPreview: View {
    let shell: FireworkShell2D
    private let previewDiameter: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.9),
                            .gray.opacity(0.6),
                            .black.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )

            let scale = (previewDiameter / 2) / 150.0
            
            ForEach(shell.stars) { star in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [star.color, star.color.opacity(0.6)],
                            center: .center,
                            startRadius: 0,
                            endRadius: star.size * scale * 0.5
                        )
                    )
                    .frame(width: star.size * scale, height: star.size * scale)
                    .position(
                        x: 25 + star.position.x * scale, // 50x50のビューの中心に合わせる
                        y: 25 + star.position.y * scale
                    )
                    .shadow(color: star.color.opacity(0.8), radius: 1, x: 0, y: 0)
            }
        }
    }
}
