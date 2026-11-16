#if os(macOS)
import AppKit
#endif
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// What adding books to an existing file did.
struct AppendResult {
    var data: Data
    /// Books written to the file.
    var added: Int
    /// Books left out because their ISBN was already in it.
    var skipped: Int
}

/// Writes scanned books as CSL JSON (Zotero ▸ File ▸ Import) or BibTeX.
enum ExportService {
    /// The formats Zotero can import, as listed in its documentation.
    enum Format: String, CaseIterable, Identifiable {
        case cslJSON, bibtex, biblatex, ris, refer, refworks, webOfScience
        case mods, marcxml, marc, endnoteXML, zoteroRDF, bibliontology, dublinCore, contextObject
        /// A spreadsheet rather than a Zotero format.
        case xlsx, csv

        var id: String { rawValue }

        /// Shown first in the export menus; everything else is under "More…".
        static let common: [Format] = [.ris, .bibtex, .xlsx, .csv]
        static let more: [Format] = allCases.filter { !common.contains($0) }

        /// The name Zotero uses for the format.
        var title: String {
            switch self {
            case .cslJSON: return "CSL JSON"
            case .bibtex: return "BibTeX"
            case .biblatex: return "BibLaTeX"
            case .ris: return "RIS"
            case .refer: return "Refer/BibIX"
            case .refworks: return "RefWorks Tagged"
            case .webOfScience: return "Web of Science Tagged"
            case .mods: return "MODS"
            case .marcxml: return "MARCXML"
            case .marc: return "MARC"
            case .endnoteXML: return "EndNote XML"
            case .zoteroRDF: return "Zotero RDF"
            case .bibliontology: return "Bibliontology RDF"
            case .dublinCore: return "Dublin Core RDF"
            case .contextObject: return "XML ContextObject"
            case .xlsx: return "Excel Workbook"
            case .csv: return "CSV"
            }
        }

        var fileExtension: String {
            switch self {
            case .cslJSON: return "json"
            case .bibtex, .biblatex: return "bib"
            case .ris: return "ris"
            case .refer, .refworks, .webOfScience: return "txt"
            case .mods, .marcxml, .endnoteXML: return "xml"
            case .marc: return "marc"
            case .zoteroRDF, .bibliontology, .dublinCore: return "rdf"
            case .contextObject: return "ctx"
            case .xlsx: return "xlsx"
            case .csv: return "csv"
            }
        }

        var contentType: UTType {
            switch self {
            case .cslJSON: return .json
            case .mods, .marcxml, .endnoteXML: return .xml
            case .refer, .refworks, .webOfScience: return .plainText
            case .xlsx: return Format.excelType
            case .csv: return .commaSeparatedText
            default: return UTType(filenameExtension: fileExtension) ?? .data
            }
        }

        var mimeType: String {
            switch self {
            case .cslJSON: return "application/json"
            case .mods, .marcxml, .endnoteXML, .contextObject: return "application/xml"
            case .zoteroRDF, .bibliontology, .dublinCore: return "application/rdf+xml"
            case .marc: return "application/marc"
            case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            case .csv: return "text/csv"
            default: return "text/plain"
            }
        }

        static let excelType = UTType("org.openxmlformats.spreadsheetml.sheet") ?? UTType(filenameExtension: "xlsx") ?? .data

        /// "Refer/BibIX" has a slash, which can't go in a file name.
        var fileName: String { "ElmScanner Export (\(title.replacingOccurrences(of: "/", with: "-"))).\(fileExtension)" }
    }

    static func data(for books: [BookMetadata], format: Format) throws -> Data {
        switch format {
        case .cslJSON: return try cslJSON(books)
        case .bibtex: return Data(bibtex(books).utf8)
        case .biblatex: return Data(biblatex(books).utf8)
        case .ris: return Data(ris(books).utf8)
        case .refer: return Data(refer(books).utf8)
        case .refworks: return Data(refworks(books).utf8)
        case .webOfScience: return Data(webOfScience(books).utf8)
        case .mods: return Data(mods(books).utf8)
        case .marcxml: return Data(marcxml(books).utf8)
        case .marc: return marc(books)
        case .endnoteXML: return Data(endnoteXML(books).utf8)
        case .zoteroRDF: return Data(zoteroRDF(books).utf8)
        case .bibliontology: return Data(bibliontologyRDF(books).utf8)
        case .dublinCore: return Data(dublinCoreRDF(books).utf8)
        case .contextObject: return Data(contextObject(books).utf8)
        case .xlsx: return try XLSX.create(books)
        case .csv: return CSVFile.create(books)
        }
    }

    #if os(macOS)
    /// Asks where to save, then writes. Returns a message to show, or nil if cancelled.
    @MainActor
    static func exportWithSavePanel(_ books: [BookMetadata], format: Format) -> (message: String, succeeded: Bool)? {
        guard !books.isEmpty else { return nil }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = format.fileName
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try data(for: books, format: format).write(to: url)
            return (String(localized: "Exported \(books.count) books."), true)
        } catch {
            return (String(localized: "Couldn't export: \(error.localizedDescription)"), false)
        }
    }


    /// Asks which Excel file to add to, then adds the books to its first sheet. Returns a message to show, or nil if cancelled.
    @MainActor
    static func appendWithOpenPanel(_ books: [BookMetadata], format: Format) -> (message: String, succeeded: Bool)? {
        guard !books.isEmpty else { return nil }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [format.contentType]
        panel.allowsMultipleSelection = false
        panel.message = format == .csv
            ? String(localized: "Choose the CSV file to add these books to.")
            : String(localized: "Choose the Excel file to add these books to.")
        panel.prompt = String(localized: "Add")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return append(books, toFileAt: url)
    }
    #endif

    /// Adds the books to an Excel file in place, and says what happened.
    static func append(_ books: [BookMetadata], toFileAt url: URL) -> (message: String, succeeded: Bool) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var outcome: Result<AppendResult, Error> = .failure(CocoaError(.fileReadUnknown))
        var coordinationError: NSError?
        // Coordinated, so a file in iCloud Drive is read and replaced safely.
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinationError) { location in
            outcome = Result {
                let contents = try Data(contentsOf: location)
                let appended = location.pathExtension.lowercased() == "csv"
                    ? try CSVFile.append(books, to: contents)
                    : try XLSX.append(books, to: contents)
                if appended.added > 0 { try appended.data.write(to: location) }
                return appended
            }
        }
        if let coordinationError { outcome = .failure(coordinationError) }
        let name = url.lastPathComponent
        switch outcome {
        case .success(let result) where result.added == 0:
            return (String(localized: "All of these books are already in \(name)."), true)
        case .success(let result):
            let added = String(localized: "\(result.added) books")
            if result.skipped == 0 { return (String(localized: "Added \(added) to \(name)."), true) }
            let skipped = String(localized: "\(result.skipped) books")
            return (String(localized: "Added \(added) to \(name). Skipped \(skipped) already in it."), true)
        case .failure(let error):
            return (String(localized: "Couldn't add to the file: \(error.localizedDescription)"), false)
        }
    }

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
            fields.append(("author", bibAuthors(book.authors)))
        }
        if let publisher = book.publisher { fields.append(("publisher", publisher)) }
        if let place = book.place { fields.append(("address", place)) }
        if let year = book.publicationYear { fields.append(("year", String(year))) }
        fields.append(("isbn", book.isbn))
        if let url = book.url { fields.append(("url", url)) }
        let body = fields.map { key, value in "  \(key) = {\(key == "author" ? value : escape(value))}" }.joined(separator: ",\n")
        return "@book{\(citeKey(for: book, usedKeys: &usedKeys)),\n\(body)\n}"
    }

    /// Braces would unbalance the entry; the rest is left as-is (BibTeX
    /// tools accept UTF-8, and {…} protects the case of the whole value).
    /// The author field: "Family, Given" joined with "and"; an organization goes in its own
    /// braces so it isn't split into names. Braces inside a name are escaped here, since
    /// the whole field is left alone afterwards.
    static func bibAuthors(_ authors: [AuthorName]) -> String {
        authors.map {
            $0.isOrganization
                ? "{\(escape($0.familyName))}"
                : "\(escape($0.familyName)), \(escape($0.givenName))"
        }.joined(separator: " and ")
    }

    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "{", with: "(").replacingOccurrences(of: "}", with: ")")
    }
}

/// The exported file, handed to SwiftUI's file exporter (the Files app on iPhone).
struct ExportDocument: FileDocument {
    static let bibType = UTType(filenameExtension: "bib") ?? .plainText
    static var readableContentTypes: [UTType] {
        [.json, .plainText, .xml, .data, bibType] + ExportService.Format.allCases.map(\.contentType)
    }
    static var writableContentTypes: [UTType] { readableContentTypes }

    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
