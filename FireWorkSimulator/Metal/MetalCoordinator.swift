// MetalCoordinator.swift

import MetalKit
import Combine
import simd

/// Metalのセットアップ、描画ループ、イベントハンドリングを担当するクラス
class MetalCoordinator: NSObject, MTKViewDelegate {
    
    // MARK: - Properties
    
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var depthState: MTLDepthStencilState?
    
    private var particles: [Particle] = []
    private let gravity = SIMD3<Float>(0, -2.5, 0) // 重力を少し強く
    
    private var viewModel: MetalViewModel
    private var cancellables = Set<AnyCancellable>()
    
    weak var parentView: MTKView?

    private var viewMatrix: simd_float4x4 = matrix_identity_float4x4
    private var projectionMatrix: simd_float4x4 = matrix_identity_float4x4

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
        
        // MARK: - 修正点2: アルファブレンディングを有効化
        // これがないと、シェーダーで計算した透明度が反映されず、ただの四角形になる
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
            shellPayload: shell
        )
        particles.append(riser)
        parentView?.setNeedsDisplay()
    }

    // MARK: - 修正点3: 爆発ロジックの修正
    // 新しいパーティクルの配列を返すように変更
    private func explode(at position: SIMD3<Float>, shell: FireworkShell2D) -> [Particle] {
        var newStars: [Particle] = []
        let explosionSpeed: Float = 4.0 // 爆発の勢いを少し強く
        
        for star2d in shell.stars {
            let baseVelocity = SIMD3<Float>(
                Float(star2d.position.x / 150.0), // キャンバス半径で正規化
                Float(star2d.position.y / 150.0),
                Float.random(in: -0.5...0.5) // Z軸にも広がりを持たせる
            )
            
            let normalizedVelocity = normalize(baseVelocity) * explosionSpeed
            
            let uiColor = UIColor(star2d.color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            let newStar = Particle(
                position: position,
                velocity: normalizedVelocity,
                color: SIMD4<Float>(Float(r), Float(g), Float(b), Float(a)),
                size: Float(star2d.size / 60.0),
                lifetime: 2.0,
                type: .star
            )
            newStars.append(newStar)
        }
        return newStars
    }

    // MARK: - MTKViewDelegate Methods

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        let deltaTime: Float = 1.0 / 60.0
        
        // --- 物理シミュレーション ---
        // MARK: - 修正点3: 寿命と爆発の管理ロジックを修正
        var nextFrameParticles: [Particle] = []
        for var particle in particles {
            particle.lifetime -= deltaTime
            
            if particle.lifetime > 0 {
                // 生きているパーティクルの物理演算
                if particle.type == .star {
                    particle.velocity += gravity * deltaTime
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

        // 各Particleを描画
        for particle in particles {
            // Particleの位置を表す平行移動行列
            let translationMatrix = simd_float4x4(translation: particle.position)
            
            // MARK: - 修正点1: 正しいビルボード行列の計算
            // カメラの回転を打ち消し、常に正面を向くようにする
            var cameraRotation = viewMatrix
            cameraRotation.columns.3 = SIMD4<Float>(0, 0, 0, 1) // カメラの移動成分を消去
            let billboardMatrix = cameraRotation.inverse
            
            let modelMatrix = translationMatrix * billboardMatrix
            
            var uniforms = Uniforms(mvpMatrix: self.projectionMatrix * self.viewMatrix * modelMatrix)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

            let vertices = makeParticleVertices(size: particle.size)
            // Particle固有の色を適用
            let coloredVertices = vertices.map { Vertex(position: $0.position, color: particle.color, texCoord: $0.texCoord) }
            
            let vertexBuffer = device.makeBuffer(bytes: coloredVertices, length: MemoryLayout<Vertex>.stride * coloredVertices.count, options: [])
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// SIMD4x4のヘルパーを末尾に追加
extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        )
    }
}
