import SwiftUI

/// The iPhone's About screen: the icon, name and version, and who made it.
struct AboutView: View {
    /// The user's current rank; nil until they have one.
    var rank: Rank?
    @Environment(\.dismiss) private var dismiss
    @State private var editingEmail = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return String(localized: "Version \(short) (\(build))")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 8) {
                Image("AboutIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 128 * 0.2237, style: .continuous))
                    .shadow(radius: 6, y: 3)
                    .accessibilityHidden(true)
                    .padding(.top, 24)
                Text("ElmScanner").font(.title.bold()).padding(.top, 8)
                Text(version).font(.subheadline).foregroundStyle(.secondary)
                if let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String {
                    Text(copyright).font(.caption).foregroundStyle(.secondary)
                }
                Text("ElmScanner lets you quickly add books to Zotero and other reference management software by scanning bar codes.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal)
                if let rank {
                    VStack(spacing: 2) {
                        Text("Rank: \(rank.title)").font(.subheadline.weight(.semibold))
                        Text(rank.message).font(.footnote)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal)
                }
                Text("Prompted by Grant Jun Otsuki\nCode by Claude")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                Text(BookSources.credit)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                Text("ElmScanner is open source under the MIT license.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                Button("Change email address…") { editingEmail = true }
                    .padding(.top, 8)
                if LibrarySender.isAvailable {
                    SendToLibraryToggle()
                        .padding(.top, 16)
                        .padding(.horizontal)
                }
                TipJarSection()
                    .padding(.top, 24)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .sheet(isPresented: $editingEmail) {
            ContactEmailForm(contact: .shared, mode: .edit) { editingEmail = false }
                .presentationDetents([.medium, .large])
        }
        .presentationDetents([.large])
    }
}
