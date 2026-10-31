import SwiftUI

/// The iPhone's second screen: a preview of what will be exported. Tap a book
/// to edit it, swipe to remove it, and Export saves a file through the Files app.
struct PhoneReviewView: View {
    var session: ScanSession

    @State private var editing: ScannedBook.ID?
    @State private var format = ExportService.Format.zotero
    @State private var exportDocument = ExportDocument(data: Data())
    @State private var exporting = false
    @State private var message: String?
    @State private var mailAttachment: MailAttachment?

    var body: some View {
        List {
            ForEach(session.books) { book in
                row(book)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = book.id }
            }
            .onDelete { session.remove(Set($0.map { session.books[$0].id })) }
        }
        .overlay {
            if session.books.isEmpty { Text("No books to export").foregroundStyle(.secondary) }
        }
        .safeAreaInset(edge: .bottom) {
            Text(message ?? "Tap a book to edit it.")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(8).background(.bar)
        }
        .navigationTitle("\(session.books.count) book\(session.books.count == 1 ? "" : "s")")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Menu("Export") {
                    Section("Save to Files") {
                        Button("Zotero (CSL JSON)") { export(.zotero) }
                        Button("BibTeX") { export(.bibtex) }
                    }
                    Section("Email as Attachment") {
                        Button("Zotero (CSL JSON)") { email(.zotero) }
                        Button("BibTeX") { email(.bibtex) }
                    }
                }
                .disabled(session.foundBooks.isEmpty)
            }
        }
        .sheet(item: editingBinding) { book in
            BookEditForm(book: book) { session.update(book.id, with: $0) }
        }
        .sheet(item: $mailAttachment) { attachment in
            MailComposer(attachment: attachment) { result in
                if result == .sent {
                    message = "Email sent."
                    session.markExported()
                }
            }
            .ignoresSafeArea()
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: format.contentType,
            defaultFilename: format.fileName
        ) { result in
            switch result {
            case .success:
                message = "Exported \(session.foundBooks.count) book\(session.foundBooks.count == 1 ? "" : "s")."
                session.markExported()
            case .failure(let error):
                if (error as? CocoaError)?.code != .userCancelled { message = "Couldn't export: \(error.localizedDescription)" }
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
                Label("Not found (\(reason)). Tap to enter it by hand; it isn't exported until then.",
                      systemImage: "exclamationmark.triangle.fill")
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

    private func export(_ chosen: ExportService.Format) {
        do {
            exportDocument = ExportDocument(data: try ExportService.data(for: session.foundBooks, format: chosen))
            format = chosen
            exporting = true
        } catch {
            message = "Couldn't export: \(error.localizedDescription)"
        }
    }

    private func email(_ chosen: ExportService.Format) {
        guard MailComposer.canSend else {
            message = "Mail isn't set up on this iPhone. Add an account in Settings ▸ Mail, or save to Files."
            return
        }
        do {
            let count = session.foundBooks.count
            let when = Date.now.formatted(date: .abbreviated, time: .shortened)
            mailAttachment = MailAttachment(
                data: try ExportService.data(for: session.foundBooks, format: chosen),
                fileName: chosen.fileName,
                mimeType: chosen == .zotero ? "application/json" : "text/plain",
                subject: "ElmScanner export: \(count) book\(count == 1 ? "" : "s"), \(when)"
            )
        } catch {
            message = "Couldn't export: \(error.localizedDescription)"
        }
    }
}
