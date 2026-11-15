import AppKit
import SwiftUI

/// The tip for the build that is downloaded directly rather than from the App Store:
/// it shows a PayPal address to send to. (Apple doesn't allow this in the App Store
/// build, which uses `TipJarSection` instead.)
struct PayPalTipSection: View {
    static let address = "elm@gjotsuki.net"
    /// Matches the price of the App Store tip.
    static let displayAmount = "$3.99"

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Support ElmScanner").font(.headline)
            // swiftlint:disable:next line_length
            Text("ElmScanner is free and open source, and every feature works without a tip. If you find it useful, you can send a tip of about \(Self.displayAmount) (one coffee!) with PayPal to support its development.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(Self.address).textSelection(.enabled).font(.body.monospaced())
                Button(copied ? LocalizedStringKey("Copied") : LocalizedStringKey("Copy address"), action: copy)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.address, forType: .string)
        copied = true
    }
}
