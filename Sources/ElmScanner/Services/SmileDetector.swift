import CoreImage
import CoreMedia

/// Notices a smiling face in a camera frame, for the "Hello!" greeting over the preview.
/// Everything happens on the device, in memory: no frame is kept and nothing about a
/// face is stored or sent anywhere.
///
/// Looking for faces is far slower than reading a barcode, so it runs on its own queue and
/// never holds up the camera: at most one look is under way, and only about three frames
/// a second are offered to it.
final class SmileDetector: @unchecked Sendable {
    private let detector = CIDetector(
        ofType: CIDetectorTypeFace,
        context: nil,
        options: [CIDetectorAccuracy: CIDetectorAccuracyLow]
    )
    private let queue = DispatchQueue(label: "ElmScanner.smile-detector", qos: .utility)
    private let lock = NSLock()
    private var lastLook = Date.distantPast
    private var looking = false
    private let interval: TimeInterval = 0.35

    /// Offers a frame. If it is time and no look is under way, checks it for a smile in the
    /// background and then calls `completion` (on the detector's queue) with the result.
    func look(at sampleBuffer: CMSampleBuffer, now: Date = .now, completion: @escaping (Bool) -> Void) {
        lock.lock()
        let due = !looking && now.timeIntervalSince(lastLook) >= interval
        if due { looking = true; lastLook = now }
        lock.unlock()
        guard due, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            if due { finish() }
            return
        }
        let image = CIImage(cvPixelBuffer: pixels)   // keeps the pixels alive; the sample buffer is not held
        queue.async { [self] in
            var options: [String: Any] = [CIDetectorSmile: true]
            #if os(iOS)
            options[CIDetectorImageOrientation] = 6   // the back camera's frames are turned a quarter
            #endif
            let faces = detector?.features(in: image, options: options) ?? []
            finish()
            completion(faces.contains { ($0 as? CIFaceFeature)?.hasSmile == true })
        }
    }

    private func finish() {
        lock.lock()
        looking = false
        lock.unlock()
    }
}
