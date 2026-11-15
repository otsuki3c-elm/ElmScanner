import SwiftUI

/// A short greeting over the camera preview while someone smiles at it. The camera
/// chooses which: "Hello!" first, then one at random.
struct GreetingView: View {
    static let greetings: [LocalizedStringKey] = ["Hello!", "Hi!", "How's it going?", "Nice smile!", ":)"]
    /// Said only to someone who has scanned this many different books in all.
    static let thanksAfter = 100

    /// The greetings to pick from, given how many different books have been scanned in all.
    static func greetings(totalScanned: Int) -> [LocalizedStringKey] {
        totalScanned >= thanksAfter ? greetings + ["Thanks for using ElmScanner!"] : greetings
    }

    let greeting: LocalizedStringKey

    var body: some View {
        Text(greeting)
            .font(.system(size: 56, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.4)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 6)
            .transition(.scale.combined(with: .opacity))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
