import AppKit
import SwiftUI

@main
struct ElmScannerApp: App {
    @State private var session = ScanSession(achievements: .standard(), library: LibrarySender.shared)

    init() {
        // One window per scan; no tabs, so View > Show Tab Bar goes away.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
                #if !DIRECT_DOWNLOAD
                .task { TipJar.shared.start() }
                #endif
                .task { await LibrarySender.shared?.flush() }
        }
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ElmScanner") { showAbout() }
            }
        }
    }

    /// The standard About panel, with the credits line added under the
    /// app's name and version.
    private func showAbout() {
        let credits = NSMutableAttributedString(
            string: "ElmScanner lets you quickly add books to Zotero and other reference management software, by scanning bar codes.\n\nPrompted by Grant Jun Otsuki\nCode by Claude\nBook data from Open Library and the National Diet Library (NDL Search)",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor
            ]
        )
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }
}
