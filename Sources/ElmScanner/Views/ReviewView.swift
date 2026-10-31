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
            preview(metadata)
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

    /// The fields as they will be written to the export.
    private func preview(_ book: BookMetadata) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.fullTitle.isEmpty ? "Untitled" : book.fullTitle).font(.headline)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 2) {
                field("Authors", BookEditForm.authorsText(book.authors), missing: book.authors.isEmpty)
                field("Publisher", book.publisher, missing: book.publisher?.isEmpty ?? true)
                field("Place", book.place, missing: book.place?.isEmpty ?? true)
                field("Year", book.publicationYear.map(String.init), missing: book.publicationYear == nil)
                field("Pages", book.numberOfPages)
                field("ISBN", book.isbn)
                field("URL", book.url)
                field("Tags", book.tags.isEmpty ? nil : book.tags.joined(separator: ", "))
            }
            .font(.callout)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func field(_ label: String, _ value: String?, missing: Bool = false) -> some View {
        if let value, !value.isEmpty {
            GridRow {
                Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                Text(value).textSelection(.enabled)
            }
        } else if missing {
            GridRow {
                Text(label).foregroundStyle(.secondary)
                Label("Missing", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
            }
        }
    }

    private func export(_ format: ExportService.Format) {
        let chosen = session.books.filter { selection.contains($0.id) }.compactMap(\.metadata)
        let books = chosen.isEmpty ? session.foundBooks : chosen
        if let result = ExportService.exportWithSavePanel(books, format: format) { message = result }
    }
}

/// Edit form for one book's export fields.
struct BookEditForm: View {
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    let onSave: (BookMetadata) -> Void
    private let isbn: String

    @State private var title: String
    @State private var subtitle: String
    @State private var authors: String
    @State private var publisher: String
    @State private var place: String
    @State private var year: String
    @State private var pages: String
    @State private var url: String
    @State private var tags: String

    init(book: ScannedBook, onSave: @escaping (BookMetadata) -> Void) {
        id = book.id
        isbn = book.isbn
        self.onSave = onSave
        let m = book.metadata
        _title = State(initialValue: m?.title ?? "")
        _subtitle = State(initialValue: m?.subtitle ?? "")
        _authors = State(initialValue: Self.authorsText(m?.authors ?? []))
        _publisher = State(initialValue: m?.publisher ?? "")
        _place = State(initialValue: m?.place ?? "")
        _year = State(initialValue: m?.publicationYear.map(String.init) ?? "")
        _pages = State(initialValue: m?.numberOfPages ?? "")
        _url = State(initialValue: m?.url ?? "")
        _tags = State(initialValue: m?.tags.joined(separator: ", ") ?? "")
    }

    /// "Family, Given" per author, separated by semicolons.
    static func authorsText(_ authors: [AuthorName]) -> String {
        authors.map { $0.isOrganization ? $0.familyName : "\($0.familyName), \($0.givenName)" }.joined(separator: "; ")
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    field("Title", $title, missing: title.isEmpty)
                    field("Subtitle", $subtitle)
                    field("Authors (Family, Given; …)", $authors, missing: authors.isEmpty)
                    LabeledContent("ISBN", value: isbn)
                }
                Section {
                    field("Publisher", $publisher, missing: publisher.isEmpty)
                    field("Place of Publication", $place, missing: place.isEmpty)
                    field("Year", $year, missing: Int(year) == nil)
                    field("Pages", $pages)
                    field("URL", $url)
                    field("Tags (comma separated)", $tags)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 460)
    }

    private func field(_ label: String, _ text: Binding<String>, missing: Bool = false) -> some View {
        HStack {
            TextField(label, text: text)
            if missing {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    .help("Missing: you may want to enter it")
            }
        }
    }

    private func save() {
        func trimmed(_ text: String) -> String? {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        onSave(BookMetadata(
            title: title.trimmingCharacters(in: .whitespaces),
            subtitle: trimmed(subtitle),
            authors: authors.split(separator: ";").map { AuthorName(parsing: String($0)) }.filter { !$0.familyName.isEmpty },
            publisher: trimmed(publisher),
            place: trimmed(place),
            publicationYear: Int(year.trimmingCharacters(in: .whitespaces)),
            numberOfPages: trimmed(pages),
            isbn: isbn,
            url: trimmed(url),
            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        ))
        dismiss()
    }
}
