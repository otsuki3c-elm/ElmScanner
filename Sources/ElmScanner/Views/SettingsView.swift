import SwiftUI

/// The Mac Settings window (⌘,): the Open Library email address, and the optional tip.
struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ContactEmailForm(contact: .shared, mode: .edit)
            Divider().padding(.horizontal, 24)
            #if !DIRECT_DOWNLOAD
            SendToLibraryToggle()
                .padding(24)
                .frame(maxWidth: 460, alignment: .leading)
            Divider().padding(.horizontal, 24)
            #endif
            tip
                .padding(24)
                .frame(maxWidth: 460, alignment: .leading)
        }
    }

    /// The App Store build tips through In-App Purchase; the direct download links to PayPal.
    @ViewBuilder private var tip: some View {
        #if DIRECT_DOWNLOAD
        PayPalTipSection()
        #else
        TipJarSection()
        #endif
    }
}
