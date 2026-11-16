import AVFoundation
import SwiftUI

#if os(macOS)
/// Shows the live camera feed for a capture session.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#else
/// Shows the live camera feed for a capture session.
struct CameraPreview: UIViewRepresentable {
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { (layer as? AVCaptureVideoPreviewLayer) ?? AVCaptureVideoPreviewLayer() }
        var onRotation: ((CGFloat) -> Void)?

        /// Turns the picture to match how the screen is held, and tells the camera, so
        /// frames (and the smile check) are upright on an iPad turned sideways.
        override func layoutSubviews() {
            super.layoutSubviews()
            guard let orientation = window?.windowScene?.interfaceOrientation else { return }
            let angle: CGFloat
            switch orientation {
            case .portraitUpsideDown: angle = 270
            case .landscapeLeft: angle = 180
            case .landscapeRight: angle = 0
            default: angle = 90
            }
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            onRotation?(angle)
        }
    }

    let session: AVCaptureSession
    var onRotation: ((CGFloat) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onRotation = onRotation
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) { uiView.onRotation = onRotation }
}
#endif
