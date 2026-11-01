import QuartzCore
import SwiftUI

/// A short burst of confetti thrown out from a point, drawn with a `CAEmitterLayer`.
/// It starts when the view appears; give it a new `.id` to fire it again.
enum Confetti {
    private static let colors: [CGColor] = [
        CGColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1), CGColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1),
        CGColor(red: 1.00, green: 0.84, blue: 0.04, alpha: 1), CGColor(red: 0.30, green: 0.78, blue: 0.35, alpha: 1),
        CGColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1), CGColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1),
    ]

    /// A small white rectangle or circle; each cell tints it with `color`.
    private static func shape(circle: Bool) -> CGImage? {
        let size = CGSize(width: 14, height: 14)
        guard let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        if circle { context.fillEllipse(in: CGRect(origin: .zero, size: size)) }
        else { context.fill(CGRect(x: 0, y: 3, width: size.width, height: 8)) }
        return context.makeImage()
    }

    /// `gravity` is the downward pull: the layer's y axis runs down on iOS and up on macOS.
    static func makeLayer(gravity: CGFloat) -> CAEmitterLayer {
        let layer = CAEmitterLayer()
        layer.emitterShape = .point
        layer.birthRate = 1
        layer.emitterCells = colors.flatMap { color in
            [false, true].map { circle -> CAEmitterCell in
                let cell = CAEmitterCell()
                cell.contents = shape(circle: circle)
                cell.color = color
                cell.birthRate = 60
                cell.lifetime = 3.5
                cell.lifetimeRange = 1
                cell.velocity = 380
                cell.velocityRange = 180
                cell.emissionLongitude = 0
                cell.emissionRange = .pi * 2
                cell.yAcceleration = gravity
                cell.spin = 3
                cell.spinRange = 6
                cell.scale = 0.7
                cell.scaleRange = 0.35
                cell.alphaSpeed = -0.25
                return cell
            }
        }
        return layer
    }

    /// How long pieces keep spawning: a quick pop. Those already in the air fall on their own.
    static let burstDuration: TimeInterval = 0.25
}

#if os(macOS)
struct ConfettiView: NSViewRepresentable {
    /// Where the burst starts, in the view's own coordinates (y down); nil for the middle.
    var origin: CGPoint?

    final class Host: NSView {
        private let emitter = Confetti.makeLayer(gravity: -300)
        private var fired = false
        var origin: CGPoint?

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.addSublayer(emitter)
            emitter.birthRate = 0
        }
        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            emitter.frame = bounds
            // AppKit layers have y running up; SwiftUI's origin runs down.
            let point = origin ?? CGPoint(x: bounds.midX, y: bounds.midY)
            emitter.emitterPosition = CGPoint(x: point.x, y: bounds.height - point.y)
            guard !fired, bounds.width > 0 else { return }
            fired = true
            emitter.birthRate = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + Confetti.burstDuration) { [weak self] in self?.emitter.birthRate = 0 }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> Host {
        let host = Host()
        host.origin = origin
        return host
    }
    func updateNSView(_ nsView: Host, context: Context) { nsView.origin = origin }
}
#else
struct ConfettiView: UIViewRepresentable {
    /// Where the burst starts, in the view's own coordinates; nil for the middle.
    var origin: CGPoint?

    final class Host: UIView {
        private let emitter = Confetti.makeLayer(gravity: 300)
        private var fired = false
        var origin: CGPoint?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            layer.addSublayer(emitter)
            emitter.birthRate = 0
        }
        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            emitter.frame = bounds
            emitter.emitterPosition = origin ?? CGPoint(x: bounds.midX, y: bounds.midY)
            guard !fired, bounds.width > 0 else { return }
            fired = true
            emitter.birthRate = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + Confetti.burstDuration) { [weak self] in self?.emitter.birthRate = 0 }
        }
    }

    func makeUIView(context: Context) -> Host {
        let host = Host()
        host.origin = origin
        return host
    }
    func updateUIView(_ uiView: Host, context: Context) { uiView.origin = origin }
}
#endif
