import SwiftUI

@main
struct ElmScannerPhoneApp: App {
    @State private var session = ScanSession(storeURL: ScanSession.defaultStoreURL, achievements: .standard())

    var body: some Scene {
        WindowGroup {
            PhoneScanView(session: session)
                .task { TipJar.shared.start() }
        }
    }
}
