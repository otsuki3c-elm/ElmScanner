import SwiftUI

struct ContentView: View {
    @State private var session = ScanSession()
    @State private var camera = BarcodeCamera()
    @State private var selection = Set<UUID>()
    @State private var manualISBN = ""
    @State private var message: String?

    var body: some View {
        HSplitView {
            cameraPane
                .frame(minWidth: 320, idealWidth: 400)
            listPane
                .frame(minWidth: 360)
        }
        .frame(minWidth: 760, minHeight: 440)
        .onAppear {
            camera.onISBN = { session.add($0) }
            camera.start()
        }
        .onDisappear { camera.stop() }
    }

    private var cameraPane: some View {
        VStack(spacing: 8) {
            ZStack {
                Color.black
                switch camera.status {
                case .running, .starting:
                    CameraPreview(session: camera.session)
                case .denied:
                    notice("Camera access is off.", "Allow it in System Settings ▸ Privacy & Security ▸ Camera.")
                case .unavailable:
                    notice("No camera found.", "You can still type or paste ISBNs below.")
                case .idle:
                    notice("Camera stopped.", "")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("Hold a book's back-cover barcode up to the camera.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                TextField("Or type an ISBN", text: $manualISBN)
                    .onSubmit(addManual)
                Button("Add", action: addManual)
                    .disabled(BookLookup.normalizedISBN(manualISBN) == nil)
            }
        }
        .padding()
    }

    private func notice(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.callout)
        }
        .foregroundStyle(.white).multilineTextAlignment(.center).padding()
    }

    private var listPane: some View {
        VStack(spacing: 0) {
            List(session.books, selection: $selection) { book in
                row(book).contextMenu {
                    Button("Remove") { session.remove(selection.contains(book.id) ? selection : [book.id]) }
                }
            }
            .overlay {
                if session.books.isEmpty {
                    Text("No books scanned yet").foregroundStyle(.secondary)
                }
            }
            .onDeleteCommand { session.remove(selection) }
            Divider()
            HStack {
                if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
                Spacer()
                Menu("Export") {
                    Button("Zotero (CSL JSON)…") { export(.zotero) }
                    Button("BibTeX…") { export(.bibtex) }
                }
                .fixedSize()
                .disabled(session.foundBooks.isEmpty)
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
            }
        }
    }

    private func subtitle(_ book: BookMetadata) -> String {
        let authors = book.authors.map { $0.isOrganization ? $0.familyName : "\($0.givenName) \($0.familyName)" }
        return ([authors.joined(separator: ", ")] + [book.publisher, book.publicationYear.map(String.init)].compactMap { $0 })
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func addManual() {
        session.add(manualISBN)
        manualISBN = ""
    }

    private func export(_ format: ExportService.Format) {
        let chosen = session.books.filter { selection.contains($0.id) }.compactMap(\.metadata)
        let books = chosen.isEmpty ? session.foundBooks : chosen
        if let result = ExportService.exportWithSavePanel(books, format: format) { message = result }
    }
}
