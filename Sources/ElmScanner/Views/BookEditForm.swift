import SwiftUI

/// Edit form for one book's export fields.
struct BookEditForm: View {
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    let onSave: (BookMetadata) -> Void
    private let isbn: String

    @State private var title: String
    @State private var subtitle: String
    /// One entry per author, each as "Family, Given".
    @State private var authors: [String]
    @State private var publisher: String
    @State private var place: String
    @State private var year: String
    @State private var pages: String
    @State private var url: String
    @State private var tags: String
    @State private var note: String

    init(book: ScannedBook, onSave: @escaping (BookMetadata) -> Void) {
        id = book.id
        isbn = book.isbn
        self.onSave = onSave
        let existing = book.metadata
        _title = State(initialValue: existing?.title ?? "")
        _subtitle = State(initialValue: existing?.subtitle ?? "")
        let names = (existing?.authors ?? []).map(Self.editableAuthor)
        _authors = State(initialValue: names.isEmpty ? [""] : names)
        _publisher = State(initialValue: existing?.publisher ?? "")
        _place = State(initialValue: existing?.place ?? "")
        _year = State(initialValue: existing?.publicationYear.map(String.init) ?? "")
        _pages = State(initialValue: existing?.numberOfPages ?? "")
        _url = State(initialValue: existing?.url ?? "")
        _tags = State(initialValue: existing?.tags.joined(separator: ", ") ?? "")
        _note = State(initialValue: existing?.note ?? "")
    }

    /// "Family, Given" per author, separated by semicolons.
    static func authorsText(_ authors: [AuthorName]) -> String {
        authors.map { $0.isOrganization ? $0.familyName : "\($0.familyName), \($0.givenName)" }.joined(separator: "; ")
    }

    /// The same, for the edit field: an organization gets a trailing comma, so that
    /// "Statistical Office of the European Communities," isn't read back as a person.
    static func editableAuthors(_ authors: [AuthorName]) -> String {
        authors.map { $0.isOrganization ? "\($0.familyName)," : "\($0.familyName), \($0.givenName)" }.joined(separator: "; ")
    }

    /// One author for its own field: "Family, Given", or an organization with a trailing comma.
    static func editableAuthor(_ author: AuthorName) -> String {
        author.isOrganization ? "\(author.familyName)," : "\(author.familyName), \(author.givenName)"
    }

    static func parseAuthors(_ text: String) -> [AuthorName] {
        text.split(separator: ";").map { AuthorName(parsing: String($0)) }.filter { !$0.familyName.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    field("Title", $title, missing: title.isEmpty)
                    field("Subtitle", $subtitle)
                    ForEach(authors.indices, id: \.self) { index in
                        field("Author \(index + 1) (Family, Given)", $authors[index],
                              missing: index == 0 && authors.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty })
                    }
                    Button("Add Author", systemImage: "plus.circle") { authors.append("") }
                        .buttonStyle(.borderless)
                    LabeledContent("ISBN", value: isbn)
                }
                Section {
                    field("Publisher", $publisher, missing: publisher.isEmpty)
                    field("Place of Publication", $place, missing: place.isEmpty)
                    field("Year", $year, missing: Int(year) == nil)
                    field("Pages", $pages)
                    field("URL", $url)
                    field("Tags (comma separated)", $tags)
                    field("Note", $note)
                }
            }
            .formStyle(.grouped)
            Divider()
            #if os(macOS)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            #else
            // Opposite sides of the screen, so neither is hit by mistake.
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .controlSize(.large)
            .padding()
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 460)
        #endif
    }

    private func field(_ label: LocalizedStringResource, _ text: Binding<String>, missing: Bool = false) -> some View {
        HStack {
            ClearableTextField(label, text: text)
            if missing {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    .help("Missing: you may want to enter it")
                    .accessibilityLabel(String(localized: "\(String(localized: label)) is missing"))
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
            authors: authors.flatMap(Self.parseAuthors),
            publisher: trimmed(publisher),
            place: trimmed(place),
            publicationYear: Int(year.trimmingCharacters(in: .whitespaces)),
            numberOfPages: trimmed(pages),
            isbn: isbn,
            url: trimmed(url),
            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            note: trimmed(note)
        ))
        dismiss()
    }
}
