import SwiftUI

@main
struct ElmScannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("ElmScanner")
            .font(.largeTitle)
            .frame(minWidth: 480, minHeight: 320)
    }
}
