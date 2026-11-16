import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Asks for the user's email address and explains why. Shown at first use (it can't be
/// skipped) and again whenever the user wants to change it.
struct ContactEmailForm: View {
    enum Mode { case firstUse, edit }

    var contact: ContactEmail
    var mode: Mode
    var onDone: () -> Void = {}

    @State private var text = ""
    @State private var showError = false

    private var valid: Bool { ContactEmail.isValid(text.trimmingCharacters(in: .whitespacesAndNewlines)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if mode == .firstUse {
                logo
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                Text("Welcome to ElmScanner").font(.largeTitle.bold())
                Text("ElmScanner lets you quickly add books to Zotero and other reference management software by scanning bar codes.")
            }
            Text(mode == .firstUse ? LocalizedStringKey("Before you start") : LocalizedStringKey("Your email address")).font(.title2.bold())
            // swiftlint:disable:next line_length
            Text("ElmScanner looks up books on Open Library, a free service run by the Internet Archive. Open Library asks every app to include an email address, so that it can tell who is using its service and reach them if something goes wrong.")
            Text("Your address is sent to Open Library with each book lookup. It is stored only on this device and is not sent anywhere else.")
                .foregroundStyle(.secondary)
            HStack {
                ClearableTextField("Email address", text: $text)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .onSubmit(save)
                Button("Submit", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!valid)
            }
            .controlSize(.large)
            if showError && !valid {
                Label("Enter an address like name@example.com.", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red).font(.callout)
            }
            if mode == .edit {
                HStack {
                    Button("Cancel") { text = contact.address; onDone() }
                    Spacer()
                }
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(maxWidth: 460)
        .onAppear { text = contact.address }
    }

    /// The app icon, centered at the top of the first-run screen.
    @ViewBuilder private var logo: some View {
        #if os(macOS)
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .accessibilityHidden(true)
        #else
        Image("AboutIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 96 * 0.2237, style: .continuous))
            .shadow(radius: 4, y: 2)
            .accessibilityHidden(true)
        #endif
    }

    private func save() {
        showError = true
        if contact.save(text) { onDone() }
    }
}

extension View {
    /// Covers this view with the email prompt until the user has entered an address.
    func requiresContactEmail(_ contact: ContactEmail = .shared) -> some View {
        sheet(isPresented: Binding(get: { !contact.isSet }, set: { _ in })) {
            ContactEmailForm(contact: contact, mode: .firstUse)
                .interactiveDismissDisabled()
        }
    }
}
