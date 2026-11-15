import SwiftUI

/// The switch for sending scanned books to ElmLibrary (Settings on the Mac, About on the iPhone).
struct SendToLibraryToggle: View {
    @AppStorage(LibrarySender.enabledKey) private var enabled = false
    @State private var showingPremiumNotice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Send scanned books to ElmLibrary", isOn: $enabled)
            Text("Uses your private iCloud. ElmLibrary on your Mac adds the books automatically (a Premium feature of ElmLibrary); otherwise export a file and import it there.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: enabled) { if enabled { showingPremiumNotice = true } }
        .alert("ElmLibrary Premium required", isPresented: $showingPremiumNotice) {
            Button("OK") {}
        } message: {
            Text("Receiving books from ElmScanner requires the Premium version of ElmLibrary.")
        }
    }
}
