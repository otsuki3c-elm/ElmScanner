import Foundation

/// The National Diet Library's catalogue (NDL Search, OpenSearch API): the legal-deposit
/// record of everything published in Japan, free and without a key. Used for Japanese
/// books, which Open Library covers poorly.
enum NDL {
    /// NDL Search asks that apps using its API say so; the About screens and README do.
    static func url(isbn13: String) -> URL {
        var components = URLComponents(string: "https://ndlsearch.ndl.go.jp/api/opensearch")!
        components.queryItems = [
            URLQueryItem(name: "isbn", value: isbn13),
            URLQueryItem(name: "cnt", value: "10")
        ]
        return components.url!
    }

    /// Japanese-language publishers' ISBNs start 978-4: where NDL is asked first.
    static func isJapanese(isbn13: String) -> Bool { isbn13.hasPrefix("9784") }

    /// One `<field>` of an `<item>`: element name, its `xsi:type`, and its text.
    fileprivate struct Field { var name: String; var type: String?; var text: String }

    /// Reads an OpenSearch RSS answer and returns the first record whose ISBN is `isbn13`
    /// (ISBN-10 records included), or nil if there is none.
    static func parse(_ data: Data, isbn13: String) -> BookMetadata? {
        let reader = ItemReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        guard parser.parse() else { return nil }
        for item in reader.items {
            let isbns = item.filter { $0.name == "dc:identifier" && ($0.type ?? "").hasPrefix("dcndl:ISBN") }
            guard isbns.contains(where: { ISBN.canonical13($0.text) == isbn13 }) else { continue }
            if let book = metadata(from: item, isbn13: isbn13) { return book }
        }
        return nil
    }

    private static func metadata(from item: [Field], isbn13: String) -> BookMetadata? {
        func first(_ name: String) -> String? {
            item.first { $0.name == name && !$0.text.isEmpty }?.text
        }
        guard let title = first("dc:title") ?? first("title") else { return nil }
        let authors = item.filter { $0.name == "dc:creator" }.map { author(from: $0.text) }.filter { !$0.familyName.isEmpty }
        // Free-text subjects only: the typed ones (NDC, NDLC…) are classification codes.
        let tags = item.filter { $0.name == "dc:subject" && $0.type == nil && !$0.text.isEmpty }.map(\.text)
        return BookMetadata(
            title: title,
            subtitle: nil,
            authors: authors,
            publisher: first("dc:publisher"),
            // The record gives only a country code ("JP"), which isn't a place of publication.
            place: nil,
            publicationYear: first("dc:date").flatMap(BookLookup.year(in:)),
            numberOfPages: first("dc:extent").flatMap(pages(in:)),
            isbn: isbn13,
            url: first("link"),
            tags: Array(tags.prefix(5))
        )
    }

    /// "夏目, 漱石, 1867-1916" → family 夏目, given 漱石 (the life dates are dropped).
    static func author(from creator: String) -> AuthorName {
        let withoutDates = creator.replacingOccurrences(
            of: #",?\s*\d{3,4}\??-(\d{3,4}\??)?\s*$"#, with: "", options: .regularExpression)
        return AuthorName(parsing: withoutDates)
    }

    /// "563p" → "563"; "xii, 300p" → "300".
    static func pages(in extent: String) -> String? {
        let matches = extent.matches(of: /(\d+)\s*(?:p|頁|ページ)/)
        return matches.last.map { String($0.1) }
    }

    private final class ItemReader: NSObject, XMLParserDelegate {
        var items: [[Field]] = []
        private var current: [Field]?
        private var field: Field?

        func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            if element == "item" { current = [] }
            else if current != nil { field = Field(name: element, type: attributes["xsi:type"], text: "") }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { field?.text += string }
        func parser(_ parser: XMLParser, foundCDATA data: Data) {}

        func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
            if element == "item", let current { items.append(current); self.current = nil }
            else if var finished = field, finished.name == element {
                finished.text = finished.text.trimmingCharacters(in: .whitespacesAndNewlines)
                current?.append(finished)
                field = nil
            }
        }
    }
}
