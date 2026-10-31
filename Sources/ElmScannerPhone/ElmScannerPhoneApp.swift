import SwiftUI

@main
struct ElmScannerPhoneApp: App {
    @State private var session = ScanSession(storeURL: ScanSession.defaultStoreURL)

    var body: some Scene {
        WindowGroup {
            PhoneScanView(session: session)
        }
    }
}
