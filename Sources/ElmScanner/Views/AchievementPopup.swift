import SwiftUI

/// The camera display's frame, so the confetti can burst from its middle.
struct CameraBoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = nextValue() ?? value }
}

extension View {
    /// Marks this view as the camera display.
    func cameraDisplay() -> some View { anchorPreference(key: CameraBoundsKey.self, value: .bounds) { $0 } }

    /// Lays the "new rank" popup over this view, with confetti bursting from the camera display.
    func achievementPopup(_ tracker: AchievementTracker?) -> some View {
        overlayPreferenceValue(CameraBoundsKey.self) { anchor in
            GeometryReader { geometry in
                if let tracker {
                    AchievementPopup(
                        tracker: tracker,
                        origin: anchor.map { CGPoint(x: geometry[$0].midX, y: geometry[$0].midY) }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// The "new rank" popup, laid over the scan screen until dismissed.
struct AchievementPopup: View {
    var tracker: AchievementTracker
    /// Where the confetti bursts from, in this view's coordinates; nil for the middle.
    var origin: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let award = tracker.pending {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { tracker.dismiss() }
                    .transition(.opacity)
                // Confetti thrown out from the camera display, behind the card; skipped when Reduce Motion is on.
                if !reduceMotion {
                    ConfettiView(origin: origin).id(award.id).ignoresSafeArea().allowsHitTesting(false)
                }
                card(award)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: tracker.pending)
        #if os(iOS)
        .onChange(of: tracker.pending) {
            if tracker.pending != nil { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        #endif
    }

    private func card(_ award: Award) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "rosette")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: award.id)
            Text("New rank!").font(.subheadline).foregroundStyle(.secondary)
            Text(award.rank.title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(award.rank.message).font(.callout).multilineTextAlignment(.center)
            Text("\(award.count) book\(award.count == 1 ? "" : "s") scanned")
                .font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
            Button("OK") { tracker.dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 20)
        .padding()
        .accessibilityElement(children: .contain)
    }
}
