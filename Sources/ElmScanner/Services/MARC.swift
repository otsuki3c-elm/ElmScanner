import Foundation

/// One field of a MARC record: a three-digit tag and its coded subfields.
struct MARCField {
    var tag: String
    var subfields: [(code: String, text: String)] = []

    /// The first subfield with this code.
    func first(_ code: String) -> String? { subfields.first { $0.code == code }?.text }

    /// Every subfield with this code.
    func all(_ code: String) -> [String] { subfields.filter { $0.code == code }.map(\.text) }
}

/// A bibliographic record in MARC (MARC 21 from the Deutsche Nationalbibliothek, UNIMARC from
/// the Bibliothèque nationale de France), with the few lookups the parsers need.
struct MARCRecord {
    var control: [String: String] = [:]
    var fields: [MARCField] = []

    func fields(_ tag: String) -> [MARCField] { fields.filter { $0.tag == tag } }

    /// The first subfield `code` of the first field `tag`.
    func first(_ tag: String, _ code: String) -> String? {
        fields.first { $0.tag == tag && $0.first(code) != nil }?.first(code)
    }

    /// Reads every record out of an SRU answer in a MARC-XML schema (MARC21 slim, or the
    /// BnF's "unimarcxchange"). Namespace prefixes (`mxc:` and the like) are ignored.
    static func records(in data: Data) -> [MARCRecord]? {
        let reader = Reader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        return parser.parse() ? reader.records : nil
    }

    private final class Reader: NSObject, XMLParserDelegate {
        var records: [MARCRecord] = []
        private var current: MARCRecord?
        private var inRecordData = false
        private var field: MARCField?
        private var controlTag: String?
        private var subfieldCode: String?
        private var text = ""

        func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            switch element.split(separator: ":").last.map(String.init) ?? element {
            case "recordData": inRecordData = true
            case "record" where inRecordData: current = MARCRecord()
            case "controlfield": controlTag = attributes["tag"]; text = ""
            case "datafield": field = MARCField(tag: attributes["tag"] ?? "")
            case "subfield": subfieldCode = attributes["code"]; text = ""
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

        func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
            switch element.split(separator: ":").last.map(String.init) ?? element {
            case "recordData": inRecordData = false
            case "record": if let current { records.append(current); self.current = nil }
            case "controlfield":
                if let controlTag { current?.control[controlTag] = text.trimmingCharacters(in: .whitespacesAndNewlines) }
                controlTag = nil
            case "subfield":
                if let subfieldCode { field?.subfields.append((subfieldCode, text.trimmingCharacters(in: .whitespacesAndNewlines))) }
                subfieldCode = nil
            case "datafield":
                if let finished = field { current?.fields.append(finished) }
                field = nil
            default: break
            }
        }
    }

    // MARK: MARC 21 books

    /// True if an 020 field of the record holds this ISBN (ISBN-10 or -13, with or without hyphens).
    func hasISBN020(_ isbn13: String) -> Bool {
        fields("020").contains { $0.all("a").contains { ISBN.canonical13($0) == isbn13 } }
    }

    /// The book in a MARC 21 record: 245 title, 264 (or 260) imprint, 300 extent, 650 subjects.
    /// The caller supplies the authors and the link, which differ between libraries.
    func marc21Book(isbn13: String, authors: [AuthorName], url: String?) -> BookMetadata? {
        guard let titleField = fields("245").first, let main = titleField.first("a") else { return nil }
        // "Title : subtitle" are 245 $a and $b; part number and part title are $n and $p.
        let title = ([main] + titleField.all("n") + titleField.all("p")).map(Self.clean).filter { !$0.isEmpty }.joined(separator: ". ")
        let subtitle = titleField.first("b").map(Self.clean).flatMap { $0.isEmpty ? nil : $0 }
        guard !title.isEmpty else { return nil }
        // 264 (RDA) with the publication statement, or 260 in older records.
        let publication = fields("264").first { $0.first("b") != nil } ?? fields("264").first ?? fields("260").first
        return BookMetadata(
            title: title,
            subtitle: subtitle,
            authors: authors,
            publisher: publication?.first("b").flatMap(Self.unbracketed),
            place: publication?.first("a").flatMap(Self.unbracketed),
            publicationYear: publication?.first("c").flatMap(BookLookup.year(in:)),
            numberOfPages: first("300", "a").flatMap(Self.pages(in:)),
            isbn: isbn13,
            url: url,
            tags: Array(fields("650").compactMap { $0.first("a") }.map(Self.clean).filter { !$0.isEmpty }.prefix(5))
        )
    }

    /// The names in the given fields' $a, "Family, Given" form, as authors.
    static func names(in fields: [MARCField]) -> [AuthorName] {
        fields.compactMap { $0.first("a") }.map { AuthorName(parsing: clean($0)) }.filter { !$0.familyName.isEmpty }
    }

    /// Organizations (110, 710) as authors.
    static func organizations(in record: MARCRecord) -> [AuthorName] {
        (record.fields("110") + record.fields("710")).compactMap { $0.first("a") }
            .map { AuthorName(familyName: clean($0)) }.filter { !$0.familyName.isEmpty }
    }

    // MARK: Cleaning text

    /// Strips the punctuation that cataloguing rules put between fields (" /", " :", " ;", " =", ","),
    /// the invisible "non-sorting" marks (BnF: C1 control characters; DNB: <<…>>) and extra spaces.
    static func clean(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: "<<", with: "").replacingOccurrences(of: ">>", with: "")
            .unicodeScalars.filter { !(0x80...0x9F).contains($0.value) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
        result = result.replacingOccurrences(of: #"\s*[/:;=,]+\s*$"#, with: "", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True for the placeholders catalogues write when a place or publisher isn't known
    /// ("[S.l.]", "[Erscheinungsort nicht ermittelbar]", "[s.n.]").
    static func isUnknown(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("nicht ermittelbar") || lower.contains("s.l.") || lower.contains("s. l.")
            || lower.contains("s.n.") || lower.contains("s. n.") || lower.contains("sine loco") || lower.contains("sine nomine")
    }

    /// A place or publisher without the square brackets that mark it as supplied by the cataloguer.
    static func unbracketed(_ text: String) -> String? {
        let value = clean(text).trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
        return value.isEmpty || isUnknown(text) ? nil : value
    }

    /// The last number followed by a page word ("103 S.", "351 Seiten", "1 volume 191 p"), as pages.
    static func pages(in extent: String) -> String? {
        let matches = extent.matches(of: /(\d+)\s*(?:S\b|Seiten|p\b|pages?\b)/)
        return matches.last.map { String($0.1) }
    }
}
