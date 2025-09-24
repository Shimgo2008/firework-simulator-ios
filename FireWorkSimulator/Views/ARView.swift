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
                        MetalView(viewModel: viewModel)
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

                                }
                            }
                    )
                }
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
            ShellListView(selectedShell: $selectedShell)
        }
        .sheet(isPresented: $isShowingP2PRoomView) {
            P2PRoomView()
        }
    }


    // MARK: - UI Components

    private var topBar: some View {
        HStack {
            Button(action: { isShowingP2PRoomView = true }) { Image(systemName: "person.3.fill") }
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
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                        .background(Color.black.opacity(0.5))
                    Image(systemName: "sparkles").foregroundColor(.white).font(.title2)
                }
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                .fill(Color.black.opacity(0.8))

            let scale = (previewDiameter / 2) / 150.0
            
            ForEach(shell.stars) { star in
                Circle()
                    .fill(star.color)
                    .frame(width: star.size * scale, height: star.size * scale)
                    .position(
                        x: 25 + star.position.x * scale, // 50x50のビューの中心に合わせる
                        y: 25 + star.position.y * scale
                    )
            }
        }
    }
}
