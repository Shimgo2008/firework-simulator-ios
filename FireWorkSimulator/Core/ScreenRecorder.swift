import Foundation
import ReplayKit

class ScreenRecorder: NSObject {
    private let recorder = RPScreenRecorder.shared()
    private var isRecording = false

    func startRecording(completion: @escaping (Error?) -> Void) {
        guard !isRecording else {
            completion(nil)
            return
        }
        recorder.startRecording { error in
            if error == nil {
                self.isRecording = true
            }
            completion(error)
        }
    }

    func stopRecording(completion: @escaping (RPPreviewViewController?, Error?) -> Void) {
        guard isRecording else {
            completion(nil, nil)
            return
        }
        recorder.stopRecording { previewVC, error in
            self.isRecording = false
            completion(previewVC, error)
        }
    }
}
