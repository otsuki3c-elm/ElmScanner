import SwiftUI

/// The Mac Settings window (⌘,): the Open Library email address, and the optional tip.
struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ContactEmailForm(contact: .shared, mode: .edit)
            Divider().padding(.horizontal, 24)
            TipJarSection()
                .padding(24)
                .frame(maxWidth: 460, alignment: .leading)
        }
    }
}
