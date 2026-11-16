import Foundation

/// The Deutsche Nationalbibliothek's catalogue (SRU interface, MARC 21): the legal-deposit record
/// of German-language publications, free and without a key; its title data is published
/// under CC0. Used for German-language books (ISBN group 978-3).
enum DNB {
    static func url(isbn13: String) -> URL {
        var query = "num=\(isbn13)"
        if let isbn10 = ISBN.isbn10(fromISBN13: isbn13) { query += " or num=\(isbn10)" }
        var components = URLComponents(string: "https://services.dnb.de/sru/dnb")!
        components.queryItems = [
            URLQueryItem(name: "version", value: "1.1"),
            URLQueryItem(name: "operation", value: "searchRetrieve"),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "recordSchema", value: "MARC21-xml"),
            URLQueryItem(name: "maximumRecords", value: "5")
        ]
        return components.url!
    }

    /// German-language publishers' ISBNs start 978-3: where the DNB is asked first.
    static func isGerman(isbn13: String) -> Bool { isbn13.hasPrefix("9783") }

    /// The first record whose ISBN is `isbn13` (ISBN-10 records included), or nil.
    static func parse(_ data: Data, isbn13: String) -> BookMetadata? {
        guard let records = MARCRecord.records(in: data) else { return nil }
        for record in records where hasISBN(record, isbn13) {
            if let book = metadata(from: record, isbn13: isbn13) { return book }
        }
        return nil
    }

    private static func hasISBN(_ record: MARCRecord, _ isbn13: String) -> Bool { record.hasISBN020(isbn13) }

    private static func metadata(from record: MARCRecord, isbn13: String) -> BookMetadata? {
        record.marc21Book(isbn13: isbn13, authors: authors(in: record), url: record.control["001"].map { "https://d-nb.info/\($0)" })
    }

    /// People from 100 and 700 with the role author or editor (or none given), else any person
    /// but a translator or illustrator; failing that, the organizations in 110 and 710.
    static func authors(in record: MARCRecord) -> [AuthorName] {
        let people = record.fields("100") + record.fields("700")
        let wanted: Set<String> = ["aut", "edt", "aus", "hrsg"]
        var chosen = people.filter { field in
            let roles = field.all("4").map { $0.lowercased() }
            return roles.isEmpty || !wanted.isDisjoint(with: roles)
        }
        if chosen.isEmpty { chosen = people.filter { Set($0.all("4")).isDisjoint(with: ["trl", "ill", "pht"]) } }
        var names = MARCRecord.names(in: chosen)
        if names.isEmpty { names = MARCRecord.organizations(in: record) }
        return names
    }
}
