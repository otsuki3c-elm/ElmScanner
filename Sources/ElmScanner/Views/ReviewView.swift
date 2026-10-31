import SwiftUI

/// The second screen: every scanned book with a preview of what will be
/// exported. Double-click a row to edit it.
struct ReviewView: View {
    var session: ScanSession
    var onBack: () -> Void

    @State private var selection = Set<UUID>()
    @State private var editing: ScannedBook.ID?
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            List(session.books, selection: $selection) { book in
                row(book)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { editing = book.id }
                    .contextMenu {
                        Button("Edit…") { editing = book.id }
                        Button("Remove") { session.remove(selection.contains(book.id) ? selection : [book.id]) }
                    }
            }
            .overlay {
                if session.books.isEmpty {
                    Text("No books to export").foregroundStyle(.secondary)
                }
            }
            .contentMargins(.top, 8, for: .scrollContent)
            .onDeleteCommand { session.remove(selection) }
            Divider()
            HStack {
                Button { onBack() } label: { Label("Back", systemImage: "chevron.left") }
                Text(countText)
                    .font(.callout.weight(.medium))
                Text(message ?? "Double-click a book to edit it.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Remove") { session.remove(selection) }
                    .disabled(selection.isEmpty)
                Menu("Export") {
                    Button("Zotero (CSL JSON)…") { export(.zotero) }
                    Button("BibTeX…") { export(.bibtex) }
                }
                .fixedSize()
                .disabled(session.foundBooks.isEmpty)
            }
            .padding(10)
        }
        .sheet(item: editingBinding) { book in
            BookEditForm(book: book) { session.update(book.id, with: $0) }
        }
    }

    private var countText: String {
        let count = session.books.count
        let books = "\(count) book\(count == 1 ? "" : "s")"
        return selection.isEmpty ? books : "\(books), \(selection.count) selected"
    }

    private var editingBinding: Binding<ScannedBook?> {
        Binding(
            get: { session.books.first { $0.id == editing } },
            set: { editing = $0?.id }
        )
    }

    @ViewBuilder
    private func row(_ book: ScannedBook) -> some View {
        switch book.state {
        case .looking:
            HStack { ProgressView().controlSize(.small); Text(book.isbn).foregroundStyle(.secondary) }
        case .found(let metadata):
            ExportPreview(book: metadata)
        case .failed(let reason):
            VStack(alignment: .leading, spacing: 2) {
                Text(book.isbn).font(.headline)
                Label("Not found (\(reason)). Double-click to enter it by hand; it isn't exported until then.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
            }
            .padding(.vertical, 2)
        }
    }

    private func export(_ format: ExportService.Format) {
        let chosen = session.books.filter { selection.contains($0.id) }.compactMap(\.metadata)
        let books = chosen.isEmpty ? session.foundBooks : chosen
        if let result = ExportService.exportWithSavePanel(books, format: format) { message = result }
    }
}
