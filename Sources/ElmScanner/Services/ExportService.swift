#if os(macOS)
import AppKit
#endif
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Writes scanned books as CSL JSON (Zotero ▸ File ▸ Import) or BibTeX.
enum ExportService {
    enum Format {
        case zotero, bibtex

        var contentType: UTType {
            switch self {
            case .zotero: return .json
            case .bibtex: return UTType(filenameExtension: "bib") ?? .plainText
            }
        }
        var fileName: String {
            switch self {
            case .zotero: return "ElmScanner Export.json"
            case .bibtex: return "ElmScanner Export.bib"
            }
        }
    }

    static func data(for books: [BookMetadata], format: Format) throws -> Data {
        switch format {
        case .zotero: return try cslJSON(books)
        case .bibtex: return Data(bibtex(books).utf8)
        }
    }

    #if os(macOS)
    /// Asks where to save, then writes. Returns a message to show, or nil if cancelled.
    @MainActor
    static func exportWithSavePanel(_ books: [BookMetadata], format: Format) -> String? {
        guard !books.isEmpty else { return nil }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = format.fileName
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try data(for: books, format: format).write(to: url)
            return "Exported \(books.count) book\(books.count == 1 ? "" : "s")."
        } catch {
            return "Couldn't export: \(error.localizedDescription)"
        }
    }

    #endif

    // MARK: CSL JSON

    static func cslJSON(_ books: [BookMetadata]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: books.map(cslItem(for:)),
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    private static func cslItem(for book: BookMetadata) -> [String: Any] {
        var item: [String: Any] = ["id": book.isbn, "type": "book", "title": book.fullTitle, "ISBN": book.isbn]
        if !book.authors.isEmpty {
            item["author"] = book.authors.map { author -> [String: String] in
                author.isOrganization
                    ? ["literal": author.familyName]
                    : ["family": author.familyName, "given": author.givenName]
            }
        }
        if let publisher = book.publisher { item["publisher"] = publisher }
        if let place = book.place { item["publisher-place"] = place }
        if let year = book.publicationYear { item["issued"] = ["date-parts": [[year]]] }
        if let pages = book.numberOfPages { item["number-of-pages"] = pages }
        if let url = book.url { item["URL"] = url }
        if !book.tags.isEmpty { item["keyword"] = book.tags.joined(separator: ", ") }
        return item
    }

    // MARK: BibTeX

    static func bibtex(_ books: [BookMetadata]) -> String {
        var usedKeys = Set<String>()
        return books.map { entry(for: $0, usedKeys: &usedKeys) }.joined(separator: "\n\n") + "\n"
    }

    /// e.g. "herbert2019dune"; a letter is appended if a key repeats.
    static func citeKey(for book: BookMetadata, usedKeys: inout Set<String>) -> String {
        func ascii(_ text: String) -> String {
            text.folding(options: .diacriticInsensitive, locale: nil)
                .lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        }
        let family = ascii(book.authors.first?.familyName ?? "")
        let word = book.title.split(separator: " ")
            .map { ascii(String($0)) }
            .first { !["a", "an", "the", "of"].contains($0) && !$0.isEmpty } ?? ""
        let base = (family.isEmpty ? "unknown" : family) + (book.publicationYear.map(String.init) ?? "") + word
        var key = base
        var suffix = UnicodeScalar("a").value
        while !usedKeys.insert(key).inserted {
            key = base + String(UnicodeScalar(suffix)!)
            suffix += 1
        }
        return key
    }

    private static func entry(for book: BookMetadata, usedKeys: inout Set<String>) -> String {
        var fields: [(String, String)] = [("title", book.fullTitle)]
        if !book.authors.isEmpty {
            let names = book.authors.map { $0.isOrganization ? "{\($0.familyName)}" : "\($0.familyName), \($0.givenName)" }
            fields.append(("author", names.joined(separator: " and ")))
        }
        if let publisher = book.publisher { fields.append(("publisher", publisher)) }
        if let place = book.place { fields.append(("address", place)) }
        if let year = book.publicationYear { fields.append(("year", String(year))) }
        fields.append(("isbn", book.isbn))
        if let url = book.url { fields.append(("url", url)) }
        let body = fields.map { "  \($0.0) = {\(escape($0.1))}" }.joined(separator: ",\n")
        return "@book{\(citeKey(for: book, usedKeys: &usedKeys)),\n\(body)\n}"
    }

    /// Braces would unbalance the entry; the rest is left as-is (BibTeX
    /// tools accept UTF-8, and {…} protects the case of the whole value).
    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "{", with: "(").replacingOccurrences(of: "}", with: ")")
    }
}

/// The exported file, handed to SwiftUI's file exporter (the Files app on iPhone).
struct ExportDocument: FileDocument {
    static let bibType = UTType(filenameExtension: "bib") ?? .plainText
    static var readableContentTypes: [UTType] { [.json, .plainText, bibType] }
    static var writableContentTypes: [UTType] { readableContentTypes }

    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
