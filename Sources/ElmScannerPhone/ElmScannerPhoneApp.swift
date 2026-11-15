import SwiftUI

@main
struct ElmScannerPhoneApp: App {
    @State private var session = ScanSession(storeURL: ScanSession.defaultStoreURL, achievements: .standard(), library: LibrarySender.shared)

    var body: some Scene {
        WindowGroup {
            PhoneScanView(session: session)
                .task { TipJar.shared.start() }
                .task { await LibrarySender.shared?.flush() }
        }
    }
}
