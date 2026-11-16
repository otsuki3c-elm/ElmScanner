import AppKit
import SwiftUI

struct ContentView: View {
    var session: ScanSession
    @State private var camera = BarcodeCamera()
    @State private var selection = Set<UUID>()
    @State private var manualISBN = ""
    @State private var reviewing = false
    @State private var editing: ScannedBook.ID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feedback: ScanFeedback?
    @State private var lastFeedbackAt = Date.distantPast
    private let contact = ContactEmail.shared

    var body: some View {
        ZStack {
            if reviewing {
                ReviewView(session: session) { slide(to: false) }
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            } else {
                HStack(spacing: 0) {
                    cameraPane
                        .frame(minWidth: 320, idealWidth: 400, maxWidth: 480)
                    Divider()
                    listPane
                        .frame(minWidth: 360)
                }
                .onAppear {
                    camera.onISBN = { handle($0) }
                    camera.totalScanned = { session.achievements?.count ?? 0 }
                    camera.onOtherBarcode = { _ in show(.rejected) }
                    // Not until the email address is in: a scan would look up a book.
                    if contact.isSet { camera.start() }
                }
                .onChange(of: contact.isSet) { if contact.isSet { camera.start() } }
                .onDisappear { camera.stop() }
                .transition(reduceMotion ? .opacity : .move(edge: .leading))
            }
        }
        .clipped()
        .achievementPopup(session.achievements)
        .requiresContactEmail(contact)
        .frame(minWidth: 760, minHeight: 620)
    }

    private var editingBinding: Binding<ScannedBook?> {
        Binding(
            get: { session.books.first { $0.id == editing } },
            set: { editing = $0?.id }
        )
    }

    private func slide(to review: Bool) {
        withAnimation(.easeInOut(duration: 0.35)) { reviewing = review }
    }

    private var cameraPane: some View {
        VStack(spacing: 8) {
            ZStack {
                Color.black
                switch camera.status {
                case .running:
                    // Only once startRunning() has returned: attaching a preview layer
                    // while the camera queue is starting the session crashes AVFoundation.
                    CameraPreview(session: camera.session)
                        .overlay { if camera.smiling { GreetingView(greeting: camera.greeting) } }
                        .animation(.easeOut(duration: 0.2), value: camera.smiling)
                        .accessibilityLabel("Camera view")
                        .accessibilityHint("Hold a book's back-cover barcode up to the camera. Each scan is announced.")
                case .starting:
                    ProgressView().controlSize(.small).accessibilityLabel("Starting camera")
                case .denied:
                    notice("Camera access is off.", "Allow it in System Settings ▸ Privacy & Security ▸ Camera.")
                case .unavailable:
                    notice("No camera found.", "You can still type or paste ISBNs below.")
                case .idle:
                    notice("Camera stopped.", "")
                }
            }
            .overlay(alignment: .topTrailing) { cameraMenu }
            .overlay {
                if let feedback {
                    ScanFeedbackView(kind: feedback.kind).id(feedback.id)
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .cameraDisplay()
            Text("Hold a book's back-cover barcode up to the camera.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                ClearableTextField("Or type an ISBN", text: $manualISBN)
                    .onSubmit(addManual)
                Button("Add", action: addManual)
                    .disabled(BookLookup.normalizedISBN(manualISBN) == nil)
            }
        }
        .padding()
    }

    /// Flashes a check or X over the camera. Frames repeat the same barcode many
    /// times a second, so further reads are ignored until the last flash is done.
    private func show(_ kind: ScanFeedback.Kind) {
        guard Date().timeIntervalSince(lastFeedbackAt) > 1.5 else { return }
        lastFeedbackAt = Date()
        let shown = ScanFeedback(kind: kind)
        Announcer.post(kind == .recognized ? String(localized: "Book scanned") : String(localized: "Not a book barcode"))
        feedback = shown
        Task {
            try? await Task.sleep(for: .seconds(1))
            if feedback == shown { withAnimation(.easeOut(duration: 0.3)) { feedback = nil } }
        }
    }

    /// Pick another connected camera (shown only when there is more than one).
    @ViewBuilder private var cameraMenu: some View {
        if camera.cameras.count > 1 {
            Menu {
                ForEach(camera.cameras) { choice in
                    Button {
                        camera.select(choice.id)
                    } label: {
                        if choice.id == camera.currentID { Label(choice.name, systemImage: "checkmark") } else { Text(choice.name) }
                    }
                }
            } label: {
                Image(systemName: "video")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(8)
            .background(.black.opacity(0.45), in: Circle())
            .padding(8)
            .help("Switch Camera")
            .accessibilityLabel("Switch Camera")
            .onAppear { camera.refreshCameras() }
        }
    }

    private func notice(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.callout)
        }
        .foregroundStyle(.white).multilineTextAlignment(.center).padding()
    }

    private var listPane: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List(session.books, selection: $selection) { book in
                    HStack(spacing: 10) {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(.secondary)
                            .symbolEffect(.bounce, options: .nonRepeating, value: session.flashCounts[book.id, default: 0])
                            .accessibilityHidden(true)
                        row(book)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAction(named: "Edit") { editing = book.id }
                    .contentShape(Rectangle())
                        .onTapGesture(count: 2) { editing = book.id }
                        .contextMenu {
                            Button("Edit…") { editing = book.id }
                            Button("Remove") { session.remove(selection.contains(book.id) ? selection : [book.id]) }
                        }
                }
                .onChange(of: session.flashing) { old, new in
                    // The rescanned book is selected (the system highlight) while it flashes.
                    guard let id = new else {
                        if let old, selection == [old] { selection = [] }
                        return
                    }
                    selection = [id]
                    if reduceMotion { proxy.scrollTo(id, anchor: .center) }
                    else { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    Announcer.post(String(localized: "Already scanned"), urgent: true)
                }
            .overlay {
                if session.books.isEmpty {
                    Text("No books scanned yet").foregroundStyle(.secondary)
                }
            }
            .onDeleteCommand { session.remove(selection) }
            .sheet(item: editingBinding) { book in
                BookEditForm(book: book) { session.update(book.id, with: $0) }
            }
            }
            Divider()
            HStack {
                Text("\(session.books.count) scanned").font(.callout.weight(.medium))
                Spacer()
                Button { slide(to: true) } label: { Label("Next", systemImage: "chevron.right").labelStyle(.titleAndIcon) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(session.books.isEmpty)
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func row(_ book: ScannedBook) -> some View {
        switch book.state {
        case .looking:
            HStack { ProgressView().controlSize(.small); Text(book.isbn).foregroundStyle(.secondary) }
        case .found(let metadata):
            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.fullTitle).font(.headline)
                Text(subtitle(metadata)).font(.callout).foregroundStyle(.secondary)
            }
        case .failed(let reason):
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.isbn).font(.headline)
                    Text(reason).font(.callout).foregroundStyle(.red)
                }
                Spacer()
                Button("Retry") { session.retry(book.id) }
                    .accessibilityLabel("Retry looking up \(book.isbn)")
            }
        }
    }

    private func subtitle(_ book: BookMetadata) -> String {
        let authors = book.authors.map { $0.isOrganization ? $0.familyName : "\($0.givenName) \($0.familyName)" }
        return ([authors.joined(separator: ", ")] + [book.publisher, book.publicationYear.map(String.init)].compactMap { $0 })
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// A scanned book gets the green check; one already in the list flashes its row instead.
    private func handle(_ isbn: String) {
        switch session.add(isbn) {
        case .added: show(.recognized)
        case .duplicate(let id): session.flash(id)
        case .invalid: break
        }
    }

    private func addManual() {
        if case .duplicate(let id) = session.add(manualISBN) { session.flash(id) }
        manualISBN = ""
    }
}
