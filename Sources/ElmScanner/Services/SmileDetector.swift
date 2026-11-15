import CoreImage
import CoreMedia

/// Notices a smiling face in a camera frame, for the "Hello!" greeting over the preview.
/// Everything happens on the device, in memory: no frame is kept and nothing about a
/// face is stored or sent anywhere.
final class SmileDetector {
    private let detector = CIDetector(
        ofType: CIDetectorTypeFace,
        context: nil,
        options: [CIDetectorAccuracy: CIDetectorAccuracyLow]
    )
    private var lastLook = Date.distantPast
    /// Looking for faces is much slower than reading a barcode, so only about three
    /// frames a second are checked.
    private let interval: TimeInterval = 0.35

    /// True when a face in this frame is smiling. Call from the camera's frame queue.
    func isSmiling(in sampleBuffer: CMSampleBuffer, now: Date = .now) -> Bool? {
        guard now.timeIntervalSince(lastLook) >= interval,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        lastLook = now
        var options: [String: Any] = [CIDetectorSmile: true]
        #if os(iOS)
        options[CIDetectorImageOrientation] = 6   // the back camera's frames are turned a quarter
        #endif
        let faces = detector?.features(in: CIImage(cvPixelBuffer: pixels), options: options) ?? []
        return faces.contains { ($0 as? CIFaceFeature)?.hasSmile == true }
    }
}
