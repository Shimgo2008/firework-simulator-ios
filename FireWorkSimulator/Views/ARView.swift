import SwiftUI
import RealityKit
import ARKit
import UIKit

struct ARViewScreen: View {
    @StateObject private var shellViewModel = ShellViewModel() // ViewModelは必要
    @State private var debugDistance: Float = 20.0
    
    // --- ステップ1: シートの表示状態を管理する@State変数を追加 ---
    @State private var isShowingShellListView = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ARViewContainer(shellViewModel: shellViewModel, debugDistance: $debugDistance)
                .edgesIgnoringSafeArea(.all)
            
            // デバッグ用スライダー
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
            
            // フローティングアクションボタン
            Button(action: {
                // --- ステップ2: ボタンが押されたら状態をtrueにする ---
                print("投稿ボタンがタップされました！")
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
            .padding(20) // 右下の角からの余白
        }
        // --- ステップ3: .sheetモディファイアを追加して、状態とビューを紐付ける ---
        .sheet(isPresented: $isShowingShellListView) {
            ShellListView()
                .onAppear {
                    // このonAppearはシートが実際に表示された時に呼ばれます
                    print("ShellListSheetViewがシートとして表示されました。")
                }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let shellViewModel: ShellViewModel
    @Binding var debugDistance: Float
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // AR セッション設定（水平面検出など）
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)

        // タップジェスチャー登録
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        context.coordinator.arView = arView
        context.coordinator.shellViewModel = shellViewModel
        context.coordinator.debugDistance = debugDistance

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.debugDistance = debugDistance
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        weak var arView: ARView?
        var shellViewModel: ShellViewModel?
        var debugDistance: Float = 20.0

        /// タップされたら花火を起動
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { 
                print("❌ ARView is nil")
                return 
            }

            let tapLocation = sender.location(in: arView)
            print("📍 タップ位置: \(tapLocation)")

            // カメラの向いている方向に遠いところに花火を配置
            let cameraTransform = arView.cameraTransform
            let cameraPosition = cameraTransform.translation
            
            // カメラの前方ベクトルを正しく計算（反転）
            let cameraMatrix = cameraTransform.matrix
            let cameraForward = SIMD3<Float>(-cameraMatrix.columns.2.x, -cameraMatrix.columns.2.y, -cameraMatrix.columns.2.z)
            
            print("📷 カメラ位置: \(cameraPosition)")
            print("🎯 カメラ前方ベクトル: \(cameraForward)")
            print("📏 設定距離: \(debugDistance)m")
            
            // カメラの前方に花火を配置
            let fireworkPosition = cameraPosition + (cameraForward * debugDistance)
            
            print("🎆 花火配置位置: \(fireworkPosition)")
            print("📐 実際の距離: \(sqrt(pow(fireworkPosition.x - cameraPosition.x, 2) + pow(fireworkPosition.y - cameraPosition.y, 2) + pow(fireworkPosition.z - cameraPosition.z, 2)))m")

            // ランダムに花火玉を選択して打ち上げ
            if let randomShell = shellViewModel?.shells.randomElement() {
                print("🎇 カスタム花火を打ち上げ: \(randomShell.name)")
                print("⭐ スター数: \(randomShell.stars.count)")
                launchFirework(shell: randomShell, at: fireworkPosition)
            } else {
                print("🎆 デフォルト花火を打ち上げ")
                launchDefaultFirework(at: fireworkPosition)
            }
        }

        /// FireworkShell2Dから花火を打ち上げる
        @available(iOS 17.0, *)
        func launchFirework(shell: FireworkShell2D, at position: SIMD3<Float>) {
            guard let arView = arView else { 
                print("❌ ARView is nil in launchFirework")
                return 
            }

            print("🚀 カスタム花火開始: \(shell.name)")
            print("📊 シェル半径: \(shell.shellRadius)")
            print("🎯 配置位置: \(position)")
//            print("🎨 表示モード: \(shell.is3DMode ? "立体感優先" : "断面図優先")")

            // 花火玉のエンティティを作成
            let fireworkEntity = Entity()
            
//            if shell.is3DMode {
//                // 立体感優先モード：3D球体状にパーティクルを配置
//                launch3DFirework(shell: shell, at: position, fireworkEntity: fireworkEntity)
//            } else {
                // 断面図優先モード：2D断面図をそのまま3Dに投影
            launch2DFirework(shell: shell, at: position, fireworkEntity: fireworkEntity)
//            }

            // アンカーにくっつけて配置
            let anchor = AnchorEntity(world: position)
            anchor.addChild(fireworkEntity)
            arView.scene.addAnchor(anchor)
            
            print("✅ カスタム花火配置完了")

            // 一定時間後に自動削除（メモリ解放）
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                anchor.removeFromParent()
                print("🗑️ カスタム花火削除完了")
            }
        }
        
        /// 断面図優先モード：2D断面図をそのまま3Dに投影
        @available(iOS 17.0, *)
        private func launch2DFirework(shell: FireworkShell2D, at position: SIMD3<Float>, fireworkEntity: Entity) {
            // 各スターからパーティクルを生成（2D形状をそのまま爆発）
            for (index, star) in shell.stars.enumerated() {
                print("⭐ スター\(index + 1): 位置(\(star.position)), 色(\(star.color)), 形状(\(star.shape))")
                let particle = create2DParticleFromStar(star, shellRadius: shell.shellRadius)
                let starEntity = Entity()
                starEntity.components.set(particle)
                fireworkEntity.addChild(starEntity)
            }
        }
        
        /// 立体感優先モード：3D球体状にパーティクルを配置
        @available(iOS 17.0, *)
        private func launch3DFirework(shell: FireworkShell2D, at position: SIMD3<Float>, fireworkEntity: Entity) {
            // 各スターを3D球体表面に投影
            for (index, star) in shell.stars.enumerated() {
                print("⭐ スター\(index + 1): 位置(\(star.position)), 色(\(star.color)), 形状(\(star.shape))")
                let particle = create3DParticleFromStar(star, shellRadius: shell.shellRadius)
                let starEntity = Entity()
                starEntity.components.set(particle)
                fireworkEntity.addChild(starEntity)
            }
        }
        
        /// デフォルトの花火を打ち上げる
        @available(iOS 17.0, *)
        func launchDefaultFirework(at position: SIMD3<Float>) {
            guard let arView = arView else { 
                print("❌ ARView is nil in launchDefaultFirework")
                return 
            }

            print("🚀 デフォルト花火開始")
            print("🎯 配置位置: \(position)")

            // より現実的な花火のパーティクル効果
            var particle = ParticleEmitterComponent()
            particle.burstCount = 800
            particle.speed = 8.0
            particle.emissionDirection = [0, 1, 0] // 上に向かって飛ばす
            particle.emitterShape = .sphere
            particle.emitterShapeSize = [0.2, 0.2, 0.2]
            particle.speedVariation = 2.0

            print("📊 パーティクル設定: burstCount=\(particle.burstCount), speed=\(particle.speed)")

            // パーティクルを再生するエンティティ
            let fireworkEntity = Entity()
            fireworkEntity.components.set(particle)

            // アンカーにくっつけて配置
            let anchor = AnchorEntity(world: position)
            anchor.addChild(fireworkEntity)
            arView.scene.addAnchor(anchor)
            
            print("✅ デフォルト花火配置完了")

            // 一定時間後に自動削除（メモリ解放）
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                anchor.removeFromParent()
                print("🗑️ デフォルト花火削除完了")
            }
        }
        
        /// Star2Dから2Dパーティクルコンポーネントを作成（断面図をそのまま爆発）
        @available(iOS 17.0, *)
        private func create2DParticleFromStar(_ star: Star2D, shellRadius: CGFloat) -> ParticleEmitterComponent {
            // 2D座標をそのまま3D座標に変換
            let radius = Float(shellRadius)
            
            // 2D座標を正規化（-1.0 から 1.0 の範囲に）
            let normalizedX = Float(star.position.x) / 100.0
            let normalizedY = Float(star.position.y) / 100.0
            
            // 2D形状をそのまま3Dに投影
            let x = radius * normalizedX // 左右の位置
            let y = radius * normalizedY // 上下の位置
            let z: Float = 0.0 // 奥行きは0（平面状に配置）
            
            print("🎯 スター3D座標: (\(x), \(y), \(z))")
            print("📐 正規化座標: (\(normalizedX), \(normalizedY))")
            print("📏 2D位置: (\(star.position.x), \(star.position.y))")

            // より現実的な花火のパーティクル効果
            var particle = ParticleEmitterComponent()
            particle.burstCount = 200
            particle.speed = 6.0
            particle.emissionDirection = [x, y, z] // 2D位置方向に飛ばす
            particle.emitterShape = .sphere
            particle.emitterShapeSize = [0.1, 0.1, 0.1]
            particle.speedVariation = 2.0
            
            print("📊 2Dスター パーティクル設定: burstCount=\(particle.burstCount), speed=\(particle.speed), emissionDirection=(\(x), \(y), \(z))")
            
            return particle
        }
        
        /// Star2Dから3Dパーティクルコンポーネントを作成（立体感優先）
        @available(iOS 17.0, *)
        private func create3DParticleFromStar(_ star: Star2D, shellRadius: CGFloat) -> ParticleEmitterComponent {
            let radius = Float(shellRadius)
            
            // 2D座標を正規化
            let normalizedX = Float(star.position.x) / 100.0
            let normalizedY = Float(star.position.y) / 100.0
            
            // 3D球体表面に投影（立体感を出す）
            let theta = atan2(normalizedY, normalizedX) // 水平角度
            let phi = asin(sqrt(normalizedX * normalizedX + normalizedY * normalizedY)) // 垂直角度
            
            // 球体表面の座標を計算
            let x = radius * cos(phi) * cos(theta)
            let y = radius * cos(phi) * sin(theta)
            let z = radius * sin(phi)
            
            print("🎯 3Dスター座標: (\(x), \(y), \(z))")
            print("📐 球面座標: theta=\(theta), phi=\(phi)")

            // 3D球体状のパーティクル効果
            var particle = ParticleEmitterComponent()
            particle.burstCount = 250
            particle.speed = 7.0
            particle.emissionDirection = [x, y, z] // 球面方向に飛ばす
            particle.emitterShape = .sphere
            particle.emitterShapeSize = [0.12, 0.12, 0.12]
            particle.speedVariation = 2.5
            
            print("📊 3Dスター パーティクル設定: burstCount=\(particle.burstCount), speed=\(particle.speed), emissionDirection=(\(x), \(y), \(z))")
            
            return particle
        }
    }
}

struct ARViewScreen_Previews: PreviewProvider {
    static var previews: some View {
        ARViewScreen()
    }
} 
