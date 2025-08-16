import RealityKit
import ARKit
import SwiftUI // Colorなどのためにインポート

class ARManager {
    // ARManagerが操作するARViewへの弱参照（循環参照を防ぐ）
    private weak var arView: ARView?
    
    func setup(with arView: ARView) {
        self.arView = arView
    }
    
    // MARK: - Public API (Coordinatorから呼ばれる)
    
    /// 指定されたシェルデータから花火を打ち上げる
    func launchFirework(shell: FireworkShell2D, at position: SIMD3<Float>) {
        guard let arView = arView else { return }

        let fireworkEntity = Entity()
        
        // is3DModeに応じてパーティクルの生成方法を切り替え
        for star in shell.stars {
            let particle = createParticleFromStar(star, shell: shell)
            let starEntity = Entity()
            starEntity.components.set(particle)
            fireworkEntity.addChild(starEntity)
        }
        
        // アンカーを作成してシーンに追加
        let anchor = AnchorEntity(world: position)
        anchor.addChild(fireworkEntity)
        arView.scene.addAnchor(anchor)
        
        // 4秒後にアンカーをシーンから削除
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            anchor.removeFromParent()
        }
    }
    
    /// デフォルトの花火を打ち上げる
    func launchDefaultFirework(at position: SIMD3<Float>) {
        guard let arView = arView else { return }

        var particle = ParticleEmitterComponent()
        particle.burstCount = 800
        particle.speed = 8.0
        particle.emissionDirection = [0, 1, 0]
        particle.emitterShape = .sphere
        particle.emitterShapeSize = [0.2, 0.2, 0.2]
        particle.speedVariation = 2.0
        
        let fireworkEntity = Entity()
        fireworkEntity.components.set(particle)
        
        let anchor = AnchorEntity(world: position)
        anchor.addChild(fireworkEntity)
        arView.scene.addAnchor(anchor)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            anchor.removeFromParent()
        }
    }
    
    // MARK: - Private Particle Creation Logic
    
    /// Star2Dデータとシェルの設定からパーティクルコンポーネントを生成する
    private func createParticleFromStar(_ star: Star2D, shell: FireworkShell2D) -> ParticleEmitterComponent {
        let shellRadius = Float(shell.shellRadius)
        
        // 2D座標を正規化（-1.0 ~ 1.0の範囲を想定）
        let normalizedX = Float(star.position.x) / 100.0
        let normalizedY = Float(star.position.y) / 100.0
        
        var particle = ParticleEmitterComponent()
        particle.emitterShape = .sphere
        

        // 断面図優先モード：2D断面図をそのまま3Dに投影
        let x = shellRadius * normalizedX
        let y = shellRadius * normalizedY
        let z: Float = 0.0 // 奥行きは0
        
        particle.burstCount = 200
        particle.speed = 6.0
        particle.emissionDirection = [x, y, z]
        particle.emitterShapeSize = [0.1, 0.1, 0.1]
        particle.speedVariation = 2.0
        
        // ここで星の色をパーティクルに反映させるロジックを追加可能
        // particle.color = .evolving(...)
        
        return particle
    }
}
