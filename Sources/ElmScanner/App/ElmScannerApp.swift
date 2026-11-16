import AppKit
import SwiftUI

@main
struct ElmScannerApp: App {
    @State private var session = ScanSession(achievements: .standard(), library: LibrarySender.shared)
    @Environment(\.openWindow) private var openWindow

    private static let privacyURL = URL(string: "https://github.com/otsuki3c-elm/ElmScanner/blob/main/docs/PRIVACY.md")!
    private static let issuesURL = URL(string: "https://github.com/otsuki3c-elm/ElmScanner/issues")!

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
        Window("ElmScanner Help", id: "help") {
            HelpView()
        }
        Window("About ElmScanner", id: "about") {
            MacAboutView(session: session)
        }
        .windowResizability(.contentSize)
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("ElmScanner Help") { openWindow(id: "help") }
                    .keyboardShortcut("?")
                Divider()
                Link("Privacy Policy", destination: Self.privacyURL)
                Link("Report an Issue…", destination: Self.issuesURL)
            }
            CommandGroup(replacing: .appInfo) {
                Button("About ElmScanner") { openWindow(id: "about") }
            }
        }
    }

}
