import SwiftUI

/// The second screen: every scanned book with a preview of what will be
/// exported. Double-click a row to edit it.
struct ReviewView: View {
    var session: ScanSession
    var onBack: () -> Void

    @State private var selection = Set<UUID>()
    @State private var editing: ScannedBook.ID?
    @State private var message: String?
    /// True once an export has worked: then "Done" appears.
    @State private var exported = false
    /// After exporting only some books: which ones, and whether the question about clearing them is showing.
    @State private var justExported = Set<UUID>()
    @State private var askingToClear = false

    var body: some View {
        VStack(spacing: 0) {
            List(session.books, selection: $selection) { book in
                row(book)
                    .accessibilityElement(children: .combine)
                    .accessibilityAction(named: "Edit") { editing = book.id }
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
                Text(message ?? String(localized: "Double-click a book to edit it."))
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button(selection.isEmpty ? LocalizedStringKey("Remove") : LocalizedStringKey("Remove Selected")) { session.remove(selection) }
                    .disabled(selection.isEmpty)
                if exported {
                    Button("Done") { finish() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
                Menu(selection.isEmpty ? LocalizedStringKey("Export") : LocalizedStringKey("Export Selected")) {
                    ForEach(ExportService.Format.common) { format in
                        if format == .xlsx || format == .csv {
                            // One more choice: a new file, or add to one made earlier.
                            Menu(format.title) {
                                Button("New File…") { export(format) }
                                Button("Add to Existing File…") { addToFile(format) }
                            }
                        } else {
                            Button("\(format.title)…") { export(format) }
                        }
                    }
                    Menu("More…") {
                        ForEach(ExportService.Format.more) { format in
                            Button("\(format.title)…") { export(format) }
                        }
                    }
                }
                .fixedSize()
                .disabled(exportSet().books.isEmpty)
            }
            .padding(10)
        }
        .onChange(of: message) { if let message { Announcer.post(message) } }
        .onAppear { if DemoMode.opensEditor { editing = session.books.first?.id } }
        .confirmationDialog("Remove the \(justExported.count) exported books from the list?", isPresented: $askingToClear, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                session.remove(justExported)
                selection.subtract(justExported)
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The books you didn't export stay in the list.")
        }
        .sheet(item: editingBinding) { book in
            BookEditForm(book: book) { session.update(book.id, with: $0) }
        }
    }

    private var countText: String {
        let count = session.books.count
        let books = String(localized: "\(count) books")
        return selection.isEmpty ? books : String(localized: "\(books), \(selection.count) selected")
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
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(reason)
                        Text("Double-click to enter the details by hand; the book isn't exported until then.")
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.callout).foregroundStyle(.orange)
            }
            .padding(.vertical, 2)
        }
    }

    /// The books an export covers: the selected ones that were found, or all found books.
    private func exportSet() -> (books: [BookMetadata], ids: Set<UUID>, partial: Bool) {
        let chosen = session.books.filter { selection.contains($0.id) && $0.metadata != nil }
        // With rows selected, only those are exported (the button says "Export Selected").
        guard !selection.isEmpty else {
            return (session.foundBooks, Set(session.books.filter { $0.metadata != nil }.map(\.id)), false)
        }
        return (chosen.compactMap(\.metadata), Set(chosen.map(\.id)), chosen.count < session.foundBooks.count)
    }

    /// After a successful export. If only some books were exported, asks whether to clear them.
    private func record(_ result: (message: String, succeeded: Bool), exportedIDs: Set<UUID>, partial: Bool) {
        message = result.message
        guard result.succeeded else { return }
        exported = true
        if partial {
            justExported = exportedIDs
            askingToClear = true
        }
    }

    /// Clears the list and goes back to the camera.
    private func finish() {
        session.removeAll()
        onBack()
    }

    private func addToFile(_ format: ExportService.Format) {
        let set = exportSet()
        if let result = ExportService.appendWithOpenPanel(set.books, format: format) {
            record(result, exportedIDs: set.ids, partial: set.partial)
        }
    }

    private func export(_ format: ExportService.Format) {
        let set = exportSet()
        if let result = ExportService.exportWithSavePanel(set.books, format: format) {
            record(result, exportedIDs: set.ids, partial: set.partial)
        }
    }
}
