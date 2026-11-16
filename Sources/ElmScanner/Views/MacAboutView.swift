#if os(macOS)
import AppKit
import SwiftUI

/// The Mac About window: the icon, name and version, the user's rank, and who made it.
/// (A SwiftUI window rather than the standard About panel, whose size can't be changed.)
struct MacAboutView: View {
    var session: ScanSession

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return String(localized: "Version \(short) (\(build))")
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)
            Text("ElmScanner").font(.largeTitle.bold()).padding(.top, 4)
            Text(version).font(.subheadline).foregroundStyle(.secondary)
            if let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String {
                Text(copyright).font(.caption).foregroundStyle(.secondary)
            }
            Text("ElmScanner lets you quickly add books to Zotero and other reference management software by scanning bar codes.")
                .padding(.top, 16)
            if let rank = session.achievements?.currentRank {
                VStack(spacing: 2) {
                    Text("Rank: \(rank.title)").font(.headline)
                    Text(rank.message)
                }
                .padding(.top, 12)
            }
            Text("Prompted by Grant Jun Otsuki\nCode by Claude")
                .padding(.top, 16)
            Text(BookSources.credit)
                .padding(.top, 8)
            Text("ElmScanner is open source under the MIT license.")
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(32)
        .frame(width: 560)
    }
}
#endif
