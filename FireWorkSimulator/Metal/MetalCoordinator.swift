// MetalCoordinator.swift

import MetalKit
import Combine
import simd
import ARKit

/// Metalのセットアップ、描画ループ、イベントハンドリングを担当するクラス
class MetalCoordinator: NSObject, MTKViewDelegate {
    
    // MARK: - Properties
    
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var depthState: MTLDepthStencilState?
    
    private var particles: [Particle] = []
    private let gravity = SIMD3<Float>(0, -2.5, 0)
    
    // Wind and weather effects for Gen Z sparkle ✨
    private var windVector = SIMD3<Float>(Float.random(in: -1.0...1.0), 0, Float.random(in: -1.0...1.0))
    private var windChangeTimer: Float = 0.0
    private let windChangeInterval: Float = 3.0 // Change wind every 3 seconds for dynamic effects
    private var soundSpeedMPS: Float = 343.0 // Default sound speed at 20°C
    private var animationTime: Float = 0.0 // For shader animations
    
    private var viewModel: MetalViewModel
    private var cancellables = Set<AnyCancellable>()
    
    weak var parentView: MTKView?
    weak var sensoryEffectsManager: SensoryEffectsManager?
    weak var arViewRef: ARView?

    private var viewMatrix: simd_float4x4 = matrix_identity_float4x4
    private var projectionMatrix: simd_float4x4 = matrix_identity_float4x4

    private var vertexBuffer: MTLBuffer?

    // MARK: - Initializer
    
    init(viewModel: MetalViewModel) {
        self.viewModel = viewModel
        super.init()

        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal is not supported.") }
        
        setupMetal(device: device)
        subscribeToTouchEvents()
    }
    
    private func setupMetal(device: MTLDevice) {
        commandQueue = device.makeCommandQueue()

        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        let colorAttachment = pipelineDescriptor.colorAttachments[0]!
        colorAttachment.isBlendingEnabled = true
        colorAttachment.rgbBlendOperation = .add
        colorAttachment.alphaBlendOperation = .add
        colorAttachment.sourceRGBBlendFactor = .sourceAlpha
        colorAttachment.sourceAlphaBlendFactor = .sourceAlpha
        colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create render pipeline state: \(error)")
        }
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = false // 半透明オブジェクトを描画するため、深度書き込みをオフにする
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
        
        // 頂点バッファを作成（四角形の6頂点）
        let vertices = makeParticleVertices(size: 1.0)
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])
    }
    
    // MARK: - Event Handling
    
    private func subscribeToTouchEvents() {
        viewModel.launchSubject
            .sink { [weak self] (shell, position) in
                self?.launchFirework(shell: shell, from: position)
            }
            .store(in: &cancellables)

        viewModel.$viewMatrix
            .sink { [weak self] matrix in
                self?.viewMatrix = matrix
            }
            .store(in: &cancellables)

        viewModel.$projectionMatrix
            .sink { [weak self] matrix in
                self?.projectionMatrix = matrix
            }
            .store(in: &cancellables)
    }


    private func launchFirework(shell: FireworkShell2D, from startPosition: SIMD3<Float>) {
        let launchHeight: Float = 10.0
        let launchDuration: Float = 5.0
        
        let riser = Particle(
            position: startPosition,
            velocity: SIMD3<Float>(0, launchHeight / launchDuration, 0),
            color: SIMD4<Float>(0.9, 0.7, 0.4, 1.0),
            size: 0.15,
            lifetime: launchDuration,
            type: .riser,
            shellPayload: shell,
            trailEmissionTimer: 0.0,
            mass: 2.0, // Heavier riser
            windResistance: 0.2 // Less affected by wind
        )
        particles.append(riser)
        parentView?.setNeedsDisplay()
    }

    // 新しいパーティクルの配列を返すように変更
    private func explode(at position: SIMD3<Float>, shell: FireworkShell2D) -> [Particle] {
        var newStars: [Particle] = []
        let explosionSpeed: Float = 5.0 // 爆発の勢いを調整する定数
        
        // Trigger sensory effects based on camera distance 🎆
        if let arView = arViewRef {
            let cameraPosition = arView.cameraTransform.matrix.translation
            sensoryEffectsManager?.triggerExplosionEffects(at: position, cameraPosition: cameraPosition)
        }
        
        for star2d in shell.stars {
            let baseVelocity = SIMD3<Float>(
                Float(star2d.position.x / 150.0), // キャンバス半径で正規化
                Float(star2d.position.y / 150.0),
                Float.random(in: -1.0...1.0) * (length(SIMD2(x: Float(star2d.position.x), y: Float(star2d.position.y))) / 150.0) // Z軸にも広がりを持たせる
            )
            
            let velocity = baseVelocity * explosionSpeed * Float.random(in: 0.8...1.2)
            
            let uiColor = UIColor(star2d.color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            let newStar = Particle(
                position: position,
                velocity: velocity,
                color: SIMD4<Float>(Float(r), Float(g), Float(b), Float(a)),
                size: Float(star2d.size / 60.0),
                lifetime: 2.5,
                type: .star,
                shellPayload: nil,
                trailEmissionTimer: 0.008,
                mass: 0.5, // Light stars for wind effect
                windResistance: 0.8 // Highly affected by wind
            )
            newStars.append(newStar)
        }
        return newStars
    }

    // MARK: - MTKViewDelegate Methods

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        let deltaTime: Float = 1.0 / 60.0
        
        // Update animation time for shader effects
        animationTime += deltaTime
        
        // Update dynamic wind for that Gen Z sparkle ✨
        windChangeTimer += deltaTime
        if windChangeTimer >= windChangeInterval {
            windVector = SIMD3<Float>(
                Float.random(in: -2.0...2.0), // X wind component
                Float.random(in: -0.5...0.5), // Slight Y component
                Float.random(in: -2.0...2.0)  // Z wind component
            )
            windChangeTimer = 0.0
        }
        
        // --- 物理シミュレーション ---
        var nextFrameParticles: [Particle] = []
        for var particle in particles {
            particle.lifetime -= deltaTime
            
            if particle.lifetime > 0 {
                // 生きているパーティクルの物理演算
                if particle.type == .star {
                    // Apply gravity
                    particle.velocity += gravity * deltaTime
                    
                    // Apply wind force based on particle properties 🌪️
                    let windForce = windVector * particle.windResistance / particle.mass
                    particle.velocity += windForce * deltaTime
                    
                    // Air resistance for realistic motion
                    let airResistance = particle.velocity * -0.3 * deltaTime
                    particle.velocity += airResistance
                    
                    particle.trailEmissionTimer -= deltaTime
                    if particle.trailEmissionTimer <= 0{
                        let trail = Particle(
                            position: particle.position,
                            velocity: .zero,
                            color: particle.color,
                            size: particle.size * 0.5,
                            lifetime: 0.5,
                            type: .trail,
                            shellPayload: nil,
                            trailEmissionTimer: 0.0,
                            mass: 0.1,
                            windResistance: 0.9
                        )
                        nextFrameParticles.append(trail)
                        particle.trailEmissionTimer = 0.008
                    }
                }
                
                if particle.type == .riser{
                    particle.velocity += gravity * deltaTime * 0.1
                    // Minimal wind effect on risers
                    let minorWind = windVector * 0.1 * deltaTime
                    particle.velocity += minorWind
                }
                
                if particle.type == .trail {
                    // Trails are heavily affected by wind for floating effect
                    let windForce = windVector * particle.windResistance / particle.mass
                    particle.velocity += windForce * deltaTime
                }

                particle.position += particle.velocity * deltaTime
                nextFrameParticles.append(particle)
            } else {
                // 寿命が尽きたパーティクルの処理
                if particle.type == .riser, let shell = particle.shellPayload {
                    // 上昇玉が寿命を迎えたら、爆発して新しい星を生成
                    let newStars = explode(at: particle.position, shell: shell)
                    nextFrameParticles.append(contentsOf: newStars)
                }
                // 寿命が尽きた星は、何もしないので配列から消える
            }
        }
        self.particles = nextFrameParticles
        
        if !particles.isEmpty {
            DispatchQueue.main.async { view.setNeedsDisplay() }
        }
        
        // --- 描画処理 ---
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let device = view.device,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        encoder.setRenderPipelineState(pipelineState!)
        encoder.setDepthStencilState(depthState!)

        // インスタンスデータを作成
        var instances: [ParticleInstance] = []
        for particle in particles {
            // Particleの位置を表す平行移動行列
            let translationMatrix = simd_float4x4(translation: particle.position)
            
            // カメラの回転を打ち消し、常に正面を向くようにする
            var cameraRotation = viewMatrix
            cameraRotation.columns.3 = SIMD4<Float>(0, 0, 0, 1) // カメラの移動成分を消去
            let billboardMatrix = cameraRotation.inverse
            
            // サイズのスケーリング行列
            let scaleMatrix = simd_float4x4(scale: SIMD3<Float>(particle.size, particle.size, 1.0))
            
            let modelMatrix = translationMatrix * billboardMatrix * scaleMatrix
            
            let instance = ParticleInstance(modelMatrix: modelMatrix, color: particle.color)
            instances.append(instance)
        }

        if !instances.isEmpty {
            let instanceBuffer = device.makeBuffer(bytes: instances, length: MemoryLayout<ParticleInstance>.stride * instances.count, options: [])
            
            var uniforms = Uniforms(mvpMatrix: projectionMatrix * viewMatrix, time: animationTime)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)
            
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instances.count)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// SIMD4x4のヘルパー
extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        )
    }
    
    init(scale: SIMD3<Float>) {
        self.init(
            SIMD4<Float>(scale.x, 0, 0, 0),
            SIMD4<Float>(0, scale.y, 0, 0),
            SIMD4<Float>(0, 0, scale.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
}
