import SwiftUI

/// The tip for the build that is downloaded directly rather than from the App Store:
/// a link to PayPal. (Apple doesn't allow this in the App Store build, which uses
/// `TipJarSection` instead.)
struct PayPalTipSection: View {
    /// Matches the price of the App Store tip.
    static let suggestedAmount = "3.99"
    static let displayAmount = "$3.99"

    static var url: URL {
        var parts = URLComponents(string: "https://www.paypal.com/cgi-bin/webscr")!
        parts.queryItems = [
            URLQueryItem(name: "cmd", value: "_donations"),
            URLQueryItem(name: "business", value: "elm@gjotsuki.net"),
            URLQueryItem(name: "item_name", value: "ElmScanner"),
            URLQueryItem(name: "amount", value: suggestedAmount),
            URLQueryItem(name: "currency_code", value: "USD"),
        ]
        return parts.url!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Support ElmScanner").font(.headline)
            Text("ElmScanner is free and open source, and every feature works without a tip. If you find it useful, you can leave a tip of about \(Self.displayAmount) through PayPal to support its development.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: Self.url) {
                Label("Leave a tip with PayPal: \(Self.displayAmount) (one coffee!)", systemImage: "heart")
            }
        }
        .accessibilityElement(children: .contain)
    }
}
