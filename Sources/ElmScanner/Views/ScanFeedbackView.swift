import SwiftUI

/// The result of a barcode read, flashed over the camera view.
struct ScanFeedback: Equatable {
    enum Kind { case recognized, rejected }
    let id = UUID()
    let kind: Kind
}

/// An animated green check (a book was recognized) or red X (some other
/// barcode). Give it a new `.id` per feedback so the animation replays.
struct ScanFeedbackView: View {
    let kind: ScanFeedback.Kind
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var symbol: String { kind == .recognized ? "checkmark.circle.fill" : "xmark.circle.fill" }
    private var tint: Color { kind == .recognized ? .green : .red }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 96))
            .foregroundStyle(.white, tint)
            .shadow(color: .black.opacity(0.4), radius: 8)
            .scaleEffect(shown || reduceMotion ? 1 : 0.3)
            .opacity(shown ? 1 : 0)
            .rotationEffect(.degrees(kind == .rejected && !shown && !reduceMotion ? -20 : 0))
            .onAppear {
                if reduceMotion { withAnimation(.easeOut(duration: 0.15)) { shown = true } }
                else { withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { shown = true } }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
