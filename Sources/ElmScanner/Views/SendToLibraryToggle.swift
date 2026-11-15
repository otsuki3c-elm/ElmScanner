import SwiftUI

/// The switch for sending scanned books to ElmLibrary (Settings on the Mac, About on the iPhone).
struct SendToLibraryToggle: View {
    @AppStorage(LibrarySender.enabledKey) private var enabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Send scanned books to ElmLibrary", isOn: $enabled)
            Text("Uses your private iCloud. ElmLibrary on your Mac adds the books automatically (a Premium feature of ElmLibrary); otherwise export a file and import it there.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
