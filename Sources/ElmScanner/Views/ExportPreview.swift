import SwiftUI

/// One book's fields as they will be written to the export.
struct ExportPreview: View {
    let book: BookMetadata

    var body: some View {
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
}
