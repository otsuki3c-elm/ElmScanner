import SwiftUI

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
        _authors = State(initialValue: Self.editableAuthors(m?.authors ?? []))
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

    /// The same, for the edit field: an organization gets a trailing comma, so that
    /// "Statistical Office of the European Communities," isn't read back as a person.
    static func editableAuthors(_ authors: [AuthorName]) -> String {
        authors.map { $0.isOrganization ? "\($0.familyName)," : "\($0.familyName), \($0.givenName)" }.joined(separator: "; ")
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
            TextField(String(localized: label), text: text)
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
            authors: Self.parseAuthors(authors),
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
