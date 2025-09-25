import Foundation
import AVFoundation
import ARKit

class CameraCapture: NSObject {
    // 写真撮影＆保存
    func capturePhoto(from view: UIView) {
        DispatchQueue.main.async {
            UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
            let screenshot = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            guard let image = screenshot else { return }

            // 2. 必要ならクロップ(ここでは全体を保存。範囲指定は後で拡張可能)
            // let croppedImage = cropToCameraArea(image)

            DispatchQueue.global(qos: .userInitiated).async {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }
    }

    // クロップ処理(必要なら実装)
    // private func cropToCameraArea(_ image: UIImage) -> UIImage { ... }
    private let session = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) {
            session.addInput(input)
        }
        let output = AVCaptureVideoDataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            videoOutput = output
        }
        session.commitConfiguration()
    }

    
    func startRunning() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopRunning() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = .resizeAspectFill
        }
        return previewLayer
    }
}

