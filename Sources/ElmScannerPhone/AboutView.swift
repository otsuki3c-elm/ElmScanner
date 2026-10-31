import SwiftUI

/// The iPhone's About screen: the icon, name and version, and who made it.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Spacer()
                Image("AboutIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 128 * 0.2237, style: .continuous))
                    .shadow(radius: 6, y: 3)
                    .accessibilityHidden(true)
                Text("ElmScanner").font(.title.bold()).padding(.top, 8)
                Text(version).font(.subheadline).foregroundStyle(.secondary)
                Text("Prompted by Grant Jun Otsuki\nCode by Claude")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
