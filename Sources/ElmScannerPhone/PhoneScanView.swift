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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                cameraPane
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .cameraDisplay()
                    .padding([.horizontal, .top])
                HStack {
                    TextField("Or type an ISBN", text: $manualISBN)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addManual)
                    Button("Add", action: addManual)
                        .disabled(BookLookup.normalizedISBN(manualISBN) == nil)
                }
                .padding()
                ScrollViewReader { proxy in
                    // Selection only ever shows the book that was just rescanned: the
                    // system's own row highlight. Taps still open the editor.
                    List(selection: Binding(get: { session.flashing }, set: { _ in })) {
                        ForEach(session.books) { book in
                            HStack(spacing: 12) {
                                Image(systemName: "book.closed.fill")
                                    .foregroundStyle(.secondary)
                                    .symbolEffect(.bounce, options: .nonRepeating, value: session.flashCounts[book.id, default: 0])
                                row(book)
                            }
                            .tag(book.id)
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
                        UIAccessibility.post(notification: .announcement, argument: "Already scanned")
                    }
                }
                .overlay {
                    if session.books.isEmpty { Text("No books scanned yet").foregroundStyle(.secondary) }
                }
            }
            .achievementPopup(session.achievements)
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
            .sheet(isPresented: $showingAbout) { AboutView() }
            .sheet(item: editingBinding) { book in
                BookEditForm(book: book) { session.update(book.id, with: $0) }
            }
            .onAppear {
                camera.onISBN = { handle($0) }
                camera.onOtherBarcode = { _ in show(.rejected) }
                camera.start()
            }
            .onDisappear { camera.stop() }
        }
    }

    private var cameraPane: some View {
        ZStack {
            Color.black
            switch camera.status {
            case .running:
                // Only once startRunning() has returned: attaching a preview layer
                // while the camera queue is starting the session crashes AVFoundation.
                CameraPreview(session: camera.session)
            case .starting:
                ProgressView()
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
    }

    private func notice(_ title: String, _ detail: String) -> some View {
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
        feedback = shown
        Task {
            try? await Task.sleep(for: .seconds(1))
            if feedback == shown { withAnimation(.easeOut(duration: 0.3)) { feedback = nil } }
        }
    }
}
