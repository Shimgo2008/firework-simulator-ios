//
//  MetalCoordinator.swift
//  metalbenkyo-ios
//
//  Created by 岩澤慎平 on 2025/08/19.
//

import MetalKit
import Combine
import simd

/// Metalのセットアップ、描画ループ、イベントハンドリングを担当するクラス
class MetalCoordinator: NSObject, MTKViewDelegate {
    
    // MARK: - Properties
    
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var depthState: MTLDepthStencilState?
    
    private var cuboids: [Cuboid] = []
    
    private var viewModel: MetalViewModel
    private var cancellable: AnyCancellable?
    
    weak var parentView: MTKView?

    private var viewMatrix: simd_float4x4 = matrix_identity_float4x4
    private var projectionMatrix: simd_float4x4 = matrix_identity_float4x4
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer
    
    init(viewModel: MetalViewModel) {
        self.viewModel = viewModel
        super.init()

        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal is not supported.") }
        
        setupMetal(device: device)
        subscribeToTouchEvents()
    }
    
    private func setupMetal(device: MTLDevice) {
        // コマンドキューを作成
        commandQueue = device.makeCommandQueue()

        // シェーダーライブラリをロード
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")

        // レンダーパイプラインを構築
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create render pipeline state: \(error)")
        }
        
        // 深度テストの設定を作成
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }
    
    // MARK: - Event Handling
    
    private func subscribeToTouchEvents() {
        print("ちゃんねるとうろく！")
        viewModel.touchSubject
            .sink { [weak self] worldPos in
                self?.spawnCuboid(at: worldPos)
            }
            .store(in: &cancellables) // Setに格納

        // MARK: - 追加点
        // カメラ行列の更新を購読
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


    private func spawnCuboid(at worldPosition: SIMD3<Float>) {
        print("cuboid")
        let newCuboid = Cuboid(
            position: worldPosition,  // そのまま渡す
            rotation: .zero,
            dimensions: SIMD3<Float>(
                Float.random(in: 0.1...0.3),
                Float.random(in: 0.1...0.3),
                Float.random(in: 0.1...0.3)
            ),
            color: SIMD4<Float>(
                Float.random(in: 0.3...1.0),
                Float.random(in: 0.3...1.0),
                Float.random(in: 0.3...1.0),
                1.0
            ),
            lifetime: 15.0
        )
        cuboids.append(newCuboid)
        parentView?.setNeedsDisplay()
    }

    // MARK: - MTKViewDelegate Methods

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        print("draw it!")
        // アニメーション更新
        let deltaTime: Float = 1.0 / 60.0
        for i in 0..<cuboids.count {
            cuboids[i].lifetime -= deltaTime
//            cuboids[i].rotation.y += deltaTime * 0.5
//            cuboids[i].rotation.x += deltaTime * 0.2
        }
        cuboids.removeAll { $0.lifetime <= 0 }
        
        if !cuboids.isEmpty {
            DispatchQueue.main.async { view.setNeedsDisplay() }
        }
        
        // Metalオブジェクト準備
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let device = view.device,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        // パイプラインと深度テスト設定
        encoder.setRenderPipelineState(pipelineState!)
        encoder.setDepthStencilState(depthState!)

        // 各Cuboidを描画
        for cuboid in cuboids {
            let modelMatrix = cuboid.modelMatrix()
            var uniforms = Uniforms(mvpMatrix: self.projectionMatrix * self.viewMatrix * modelMatrix)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

            let vertices = makeCuboidVertices(from: cuboid)
            let vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }

        // コマンド終了と提出
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
