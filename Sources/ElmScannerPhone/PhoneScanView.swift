import SwiftUI

/// The iPhone's first screen: the camera on top, the scanned books below.
/// Tap a book to edit it; Next goes to the review screen.
struct PhoneScanView: View {
    var session: ScanSession
    @State private var camera = BarcodeCamera()
    @State private var manualISBN = ""
    @State private var editing: ScannedBook.ID?
    @State private var feedback: ScanFeedback?
    @State private var lastFeedbackAt = Date.distantPast
    @State private var reviewing = false
    @State private var confirmingClear = false
    @State private var showingAbout = false
    private let contact = ContactEmail.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    // iPad: the camera and the ISBN field on the left, the list on the right.
                    GeometryReader { geometry in
                        let portrait = geometry.size.height > geometry.size.width
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                if portrait {
                                    // Held upright: the camera takes the column's height.
                                    cameraPane
                                        .frame(maxHeight: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .cameraDisplay()
                                        .padding([.horizontal, .top])
                                    isbnField
                                } else {
                                    // Held sideways: a 3:4 camera, with the field under it.
                                    cameraPane
                                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .cameraDisplay()
                                        .padding([.horizontal, .top])
                                    isbnField
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(width: portrait ? 420 : min(480, geometry.size.width * 0.4))
                            Divider()
                            bookList
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        cameraPane
                            // Leaves room for the list when the text size is very large.
                            .frame(height: typeSize.isAccessibilitySize ? 180 : 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .cameraDisplay()
                            .padding([.horizontal, .top])
                        isbnField
                        bookList
                    }
                }
            }
            .achievementPopup(session.achievements)
            .requiresContactEmail(contact)
            .navigationTitle("\(session.books.count) scanned")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear", role: .destructive) { confirmingClear = true }
                        .disabled(session.books.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { showingAbout = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("About ElmScanner")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") { reviewing = true }.disabled(session.books.isEmpty)
                }
            }
            .confirmationDialog("Remove all \(session.books.count) scanned books?",
                                isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Remove All", role: .destructive) { session.removeAll() }
            }
            .navigationDestination(isPresented: $reviewing) { PhoneReviewView(session: session) }
            .sheet(isPresented: $showingAbout) { AboutView(rank: session.achievements?.currentRank) }
            .sheet(item: editingBinding) { book in
                BookEditForm(book: book) { session.update(book.id, with: $0) }
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
        }
    }

    private var isbnField: some View {
        HStack {
            ClearableTextField("Or type an ISBN", text: $manualISBN)
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addManual)
            Button("Add", action: addManual)
                .disabled(BookLookup.normalizedISBN(manualISBN) == nil)
        }
        .padding()
    }

    private var bookList: some View {
        ScrollViewReader { proxy in
            // Selection only ever shows the book that was just rescanned: the
            // system's own row highlight. Taps still open the editor.
            List(selection: Binding(get: { session.flashing }, set: { _ in })) {
                ForEach(session.books) { book in
                    HStack(spacing: 12) {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(.secondary)
                            .symbolEffect(.bounce, options: .nonRepeating, value: session.flashCounts[book.id, default: 0])
                            .accessibilityHidden(true)
                        row(book)
                    }
                    .tag(book.id)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Opens it for editing")
                    .contentShape(Rectangle())
                    .onTapGesture { editing = book.id }
                }
                .onDelete { session.remove(Set($0.map { session.books[$0].id })) }
            }
            .onChange(of: session.flashing) {
                guard let id = session.flashing else { return }
                if reduceMotion { proxy.scrollTo(id, anchor: .center) }
                else { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                Announcer.post(String(localized: "Already scanned"), urgent: true)
            }
        }
        .overlay {
            if session.books.isEmpty { Text("No books scanned yet").foregroundStyle(.secondary) }
        }
    }

    private var cameraPane: some View {
        ZStack {
            Color.black
            switch camera.status {
            case .running:
                // Only once startRunning() has returned: attaching a preview layer
                // while the camera queue is starting the session crashes AVFoundation.
                CameraPreview(session: camera.session, onRotation: { camera.setVideoRotation($0) })
                    .overlay { if camera.smiling { GreetingView(greeting: camera.greeting) } }
                    .animation(.easeOut(duration: 0.2), value: camera.smiling)
                    .accessibilityLabel("Camera view")
                    .accessibilityHint("Hold a book's back-cover barcode up to the camera. Each scan is announced.")
            case .starting:
                ProgressView().accessibilityLabel("Starting camera")
            case .denied:
                notice("Camera access is off.", "Allow it in Settings ▸ ElmScanner ▸ Camera.")
            case .unavailable:
                notice("No camera found.", "You can still type ISBNs below.")
            case .idle:
                notice("Camera stopped.", "")
            }
            if let feedback {
                ScanFeedbackView(kind: feedback.kind).id(feedback.id).transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            if camera.status == .running, camera.cameras.count > 1 {
                Button { camera.flip() } label: {
                    Image(systemName: "camera.rotate")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding(8)
                .accessibilityLabel("Switch Camera")
            }
        }
    }

    private func notice(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.callout)
        }
        .foregroundStyle(.white).multilineTextAlignment(.center).padding()
    }

    @ViewBuilder
    private func row(_ book: ScannedBook) -> some View {
        switch book.state {
        case .looking:
            HStack { ProgressView(); Text(book.isbn).foregroundStyle(.secondary) }
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
                Button("Retry") { session.retry(book.id) }.buttonStyle(.borderless)
                    .accessibilityLabel("Retry looking up \(book.isbn)")
            }
        }
    }

    private func subtitle(_ book: BookMetadata) -> String {
        let authors = book.authors.map { $0.isOrganization ? $0.familyName : "\($0.givenName) \($0.familyName)" }
        return ([authors.joined(separator: ", ")] + [book.publisher, book.publicationYear.map(String.init)].compactMap { $0 })
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var editingBinding: Binding<ScannedBook?> {
        Binding(
            get: { session.books.first { $0.id == editing } },
            set: { editing = $0?.id }
        )
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

    /// Flashes a check or X over the camera. Frames repeat the same barcode many
    /// times a second, so further reads are ignored until the last flash is done.
    private func show(_ kind: ScanFeedback.Kind) {
        guard Date().timeIntervalSince(lastFeedbackAt) > 1.5 else { return }
        lastFeedbackAt = Date()
        UINotificationFeedbackGenerator().notificationOccurred(kind == .recognized ? .success : .error)
        let shown = ScanFeedback(kind: kind)
        Announcer.post(kind == .recognized ? String(localized: "Book scanned") : String(localized: "Not a book barcode"))
        feedback = shown
        Task {
            try? await Task.sleep(for: .seconds(1))
            if feedback == shown { withAnimation(.easeOut(duration: 0.3)) { feedback = nil } }
        }
    }
}
