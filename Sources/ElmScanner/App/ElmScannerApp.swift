import AppKit
import SwiftUI

@main
struct ElmScannerApp: App {
    @State private var session = ScanSession(achievements: .standard())

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
        }
        Settings {
            ContactEmailForm(contact: .shared, mode: .edit)
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
            string: "Prompted by Grant Jun Otsuki\nCode by Claude\nBook data from Open Library",
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
