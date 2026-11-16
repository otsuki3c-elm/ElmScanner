import Foundation

/// The Biblioteca Nacional de España's catalogue (SRU interface, MARC 21): the legal-deposit
/// record of Spanish publications, free and without a key. Used for books published in Spain
/// (ISBN group 978-84).
enum BNE {
    static func url(isbn13: String) -> URL {
        var components = URLComponents(string: "https://catalogo.bne.es/view/sru/34BNE_INST")!
        components.queryItems = [
            URLQueryItem(name: "version", value: "1.2"),
            URLQueryItem(name: "operation", value: "searchRetrieve"),
            URLQueryItem(name: "query", value: "alma.isbn=\(isbn13)"),
            URLQueryItem(name: "recordSchema", value: "marcxml"),
            URLQueryItem(name: "maximumRecords", value: "10")
        ]
        return components.url!
    }

    /// Spanish publishers' ISBNs start 978-84: where the BNE is asked first.
    static func isSpanish(isbn13: String) -> Bool { isbn13.hasPrefix("97884") }

    /// The book for `isbn13`. The BNE holds a record for every printing, and a publisher reuses
    /// an ISBN across them, so of those that match the most recent printing is taken.
    static func parse(_ data: Data, isbn13: String) -> BookMetadata? {
        guard let records = MARCRecord.records(in: data) else { return nil }
        let books = records.filter { $0.hasISBN020(isbn13) }.compactMap {
            $0.marc21Book(isbn13: isbn13, authors: authors(in: $0), url: nil)
        }
        return books.max { ($0.publicationYear ?? 0) < ($1.publicationYear ?? 0) }
    }

    /// The main entry (100) and any added entry (700) marked as an author; if there is no
    /// main entry, added entries with no role or the author role; failing that, organizations.
    /// Editors of an edition, translators and illustrators are left out.
    static func authors(in record: MARCRecord) -> [AuthorName] {
        func isAuthor(_ field: MARCField) -> Bool {
            let roles = (field.all("4") + field.all("e")).map { $0.lowercased() }
            return roles.contains { $0.hasPrefix("aut") }
        }
        let main = record.fields("100")
        let added = record.fields("700")
        var chosen = main + added.filter(isAuthor)
        if main.isEmpty { chosen = added.filter { isAuthor($0) || ($0.all("4") + $0.all("e")).isEmpty } }
        var names = MARCRecord.names(in: chosen)
        if names.isEmpty { names = MARCRecord.organizations(in: record) }
        return names
    }
}
