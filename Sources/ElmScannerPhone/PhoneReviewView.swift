import SwiftUI

/// The iPhone's second screen: a preview of what will be exported. Tap a book
/// to edit it, swipe to remove it, and Export saves a file through the Files app.
struct PhoneReviewView: View {
    var session: ScanSession

    @Environment(\.dismiss) private var dismiss
    /// True once an export has worked: then "Done" appears.
    @State private var exported = false
    @State private var editing: ScannedBook.ID?
    @State private var format = ExportService.Format.cslJSON
    @State private var exportDocument = ExportDocument(data: Data())
    @State private var exporting = false
    @State private var addingToFile = false
    @State private var addFormat = ExportService.Format.xlsx
    @State private var message: String?
    @State private var mailAttachment: MailAttachment?

    var body: some View {
        List {
            ForEach(session.books) { book in
                row(book)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Opens it for editing")
                    .contentShape(Rectangle())
                    .onTapGesture { editing = book.id }
            }
            .onDelete { session.remove(Set($0.map { session.books[$0].id })) }
        }
        .overlay {
            if session.books.isEmpty { Text("No books to export").foregroundStyle(.secondary) }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if exported {
                    // Clears the list and goes back to the camera.
                    Button { session.removeAll(); dismiss() } label: { Text("Done").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                Text(message ?? String(localized: "Tap a book to edit it."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(8).background(.bar)
        }
        .navigationTitle("\(session.books.count) books")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // Two stages: where to send the file, then which format.
                Menu("Export") {
                    Menu("Files App", systemImage: "folder") {
                        // Excel and CSV take one more tap: a new file, or add to one made earlier.
                        formatButtons({ export($0) }, addTo: { addFormat = $0; addingToFile = true })
                    }
                    Menu("Email", systemImage: "envelope") {
                        formatButtons { email($0) }
                    }
                }
                .disabled(session.foundBooks.isEmpty)
            }
        }
        .onChange(of: message) { if let message { Announcer.post(message) } }
        .sheet(item: editingBinding) { book in
            BookEditForm(book: book) { session.update(book.id, with: $0) }
        }
        .sheet(item: $mailAttachment) { attachment in
            MailComposer(attachment: attachment) { result in
                if result == .sent {
                    message = String(localized: "Email sent.")
                    session.markExported()
                    exported = true
                }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $addingToFile, allowedContentTypes: [addFormat.contentType]) { result in
            switch result {
            case .success(let url):
                let outcome = ExportService.append(session.foundBooks, toFileAt: url)
                message = outcome.message
                if outcome.succeeded { session.markExported(); exported = true }
            case .failure(let error):
                message = String(localized: "Couldn't add to the file: \(error.localizedDescription)")
            }
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: format.contentType,
            defaultFilename: format.fileName
        ) { result in
            switch result {
            case .success:
                message = String(localized: "Exported \(session.foundBooks.count) books.")
                session.markExported()
                exported = true
            case .failure(let error):
                if (error as? CocoaError)?.code != .userCancelled { message = String(localized: "Couldn't export: \(error.localizedDescription)") }
            }
        }
    }

    @ViewBuilder
    private func row(_ book: ScannedBook) -> some View {
        switch book.state {
        case .looking:
            HStack { ProgressView(); Text(book.isbn).foregroundStyle(.secondary) }
        case .found(let metadata):
            ExportPreview(book: metadata)
        case .failed(let reason):
            VStack(alignment: .leading, spacing: 2) {
                Text(book.isbn).font(.headline)
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(reason)
                        Text("Tap to enter the details by hand; the book isn't exported until then.")
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.callout).foregroundStyle(.orange)
            }
        }
    }

    private var editingBinding: Binding<ScannedBook?> {
        Binding(
            get: { session.books.first { $0.id == editing } },
            set: { editing = $0?.id }
        )
    }

    /// RIS and BibTeX, then everything else behind "More…".
    @ViewBuilder
    private func formatButtons(_ action: @escaping (ExportService.Format) -> Void,
                               addTo: ((ExportService.Format) -> Void)? = nil) -> some View {
        ForEach(ExportService.Format.common) { format in
            if let addTo, format == .xlsx || format == .csv {
                Menu(format.title) {
                    Button("New File…") { action(format) }
                    Button(format == .xlsx ? "Add to Excel File…" : "Add to CSV File…") { addTo(format) }
                }
            } else {
                Button(format.title) { action(format) }
            }
        }
        Menu("More…") {
            ForEach(ExportService.Format.more) { format in
                Button(format.title) { action(format) }
            }
        }
    }

    private func export(_ chosen: ExportService.Format) {
        do {
            exportDocument = ExportDocument(data: try ExportService.data(for: session.foundBooks, format: chosen))
            format = chosen
            exporting = true
        } catch {
            message = String(localized: "Couldn't export: \(error.localizedDescription)")
        }
    }

    private func email(_ chosen: ExportService.Format) {
        guard MailComposer.canSend else {
            message = String(localized: "Mail isn't set up on this iPhone. Add an account in Settings ▸ Mail, or save to Files.")
            return
        }
        do {
            let count = session.foundBooks.count
            let when = Date.now.formatted(date: .abbreviated, time: .shortened)
            mailAttachment = MailAttachment(
                data: try ExportService.data(for: session.foundBooks, format: chosen),
                fileName: chosen.fileName,
                mimeType: chosen.mimeType,
                subject: String(localized: "ElmScanner export: \(String(localized: "\(count) books")), \(when)")
            )
        } catch {
            message = String(localized: "Couldn't export: \(error.localizedDescription)")
        }
    }
}
