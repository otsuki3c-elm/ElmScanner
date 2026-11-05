import StoreKit
import SwiftUI

/// "Leave a tip": an optional one-time purchase that supports the developer.
struct TipJarSection: View {
    var tipJar: TipJar = .shared
    @Environment(\.purchase) private var purchase

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Support ElmScanner").font(.headline)
            Text("ElmScanner is free and open source, and every feature works without a tip. If you find it useful, you can leave a one-time tip to support its development. The purchase is handled by Apple.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            switch tipJar.state {
            case .loading:
                ProgressView().controlSize(.small)
            case .unavailable:
                Text("Tips aren't available right now.").font(.callout).foregroundStyle(.secondary)
            case .ready, .purchasing, .failed:
                Button { Task { await tipJar.buy { try await purchase($0) } } } label: {
                    Label("Leave a tip (\(tipJar.product?.displayPrice ?? ""))", systemImage: "heart")
                }
                .disabled(tipJar.state == .purchasing)
                if case .failed(let message) = tipJar.state {
                    Text(message).font(.callout).foregroundStyle(.red)
                }
            case .thanked:
                Label("Thank you!", systemImage: "heart.fill").foregroundStyle(.pink)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
