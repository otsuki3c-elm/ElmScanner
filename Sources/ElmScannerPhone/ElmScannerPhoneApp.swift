import SwiftUI

@main
struct ElmScannerPhoneApp: App {
    @State private var session = ScanSession(storeURL: ScanSession.defaultStoreURL, achievements: .standard(), library: LibrarySender.shared)

    init() {
        // The system's clear button (ⓧ) in every text field while it is being edited.
        UITextField.appearance().clearButtonMode = .whileEditing
    }

    var body: some Scene {
        WindowGroup {
            PhoneScanView(session: session)
                .task { TipJar.shared.start() }
                .task { await LibrarySender.shared?.flush() }
        }
    }
}
