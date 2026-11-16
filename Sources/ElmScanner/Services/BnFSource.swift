import Foundation

/// The Bibliothèque nationale de France's catalogue (SRU interface, UNIMARC): the legal-deposit
/// record of French publications, free and without a key, under the Licence Ouverte. Used for
/// French-language books (ISBN groups 978-2 and 979-10).
enum BnF {
    static func url(isbn13: String) -> URL {
        // The index holds the ISBN as catalogued: records with only an ISBN-10 need that form.
        let isbns = [isbn13] + (ISBN.isbn10(fromISBN13: isbn13).map { [$0] } ?? [])
        var components = URLComponents(string: "https://catalogue.bnf.fr/api/SRU")!
        components.queryItems = [
            URLQueryItem(name: "version", value: "1.2"),
            URLQueryItem(name: "operation", value: "searchRetrieve"),
            URLQueryItem(name: "query", value: "bib.isbn any \"\(isbns.joined(separator: " "))\""),
            URLQueryItem(name: "recordSchema", value: "unimarcxchange"),
            URLQueryItem(name: "maximumRecords", value: "5")
        ]
        return components.url!
    }

    /// The credit the BnF's Licence Ouverte asks for: its name, and the date the record was taken.
    static func attribution(on date: Date) -> String {
        let day = date.formatted(.iso8601.year().month().day())
        return "Source: Bibliothèque nationale de France (catalogue.bnf.fr), Licence Ouverte, retrieved \(day)"
    }

    /// French-language publishers' ISBNs start 978-2 or 979-10: where the BnF is asked first.
    static func isFrench(isbn13: String) -> Bool { isbn13.hasPrefix("9782") || isbn13.hasPrefix("97910") }

    /// The first record whose ISBN is `isbn13` (ISBN-10 records included), or nil.
    static func parse(_ data: Data, isbn13: String) -> BookMetadata? {
        guard let records = MARCRecord.records(in: data) else { return nil }
        // A record that names the ISBN, else one with no ISBN in it at all: the catalogue's index
        // matched it (some old records are found by ISBN without holding it in a field).
        let candidates = records.filter { hasISBN($0, isbn13) } + records.filter { !hasAnyISBN($0) }
        for record in candidates {
            if let book = metadata(from: record, isbn13: isbn13) { return book }
        }
        return nil
    }

    private static func hasAnyISBN(_ record: MARCRecord) -> Bool {
        !(record.fields("010") + record.fields("073")).flatMap { $0.all("a") }.isEmpty
    }

    /// 010 holds the ISBN as printed (with hyphens); 073 the EAN-13 without.
    private static func hasISBN(_ record: MARCRecord, _ isbn13: String) -> Bool {
        (record.fields("010") + record.fields("073")).contains { field in
            field.all("a").contains { ISBN.canonical13($0) == isbn13 }
        }
    }

    private static func metadata(from record: MARCRecord, isbn13: String) -> BookMetadata? {
        guard let titleField = record.fields("200").first, let main = titleField.first("a") else { return nil }
        // 200: $a title, $h part number, $i part title, $e other title information (subtitle).
        let title = ([main] + titleField.all("h") + titleField.all("i")).map(MARCRecord.clean).filter { !$0.isEmpty }.joined(separator: ". ")
        let subtitle = titleField.first("e").map(MARCRecord.clean).flatMap { $0.isEmpty ? nil : $0 }
        guard !title.isEmpty else { return nil }

        // 210 (older) or 214 (RDA): $a place, $c publisher, $d date.
        let publication = (record.fields("214") + record.fields("210")).first { $0.first("c") != nil }
            ?? record.fields("214").first ?? record.fields("210").first
        let ark = record.control["003"].map { $0.replacingOccurrences(of: "http://", with: "https://") }
        return BookMetadata(
            title: title,
            subtitle: subtitle,
            authors: authors(in: record),
            publisher: publication?.first("c").flatMap(MARCRecord.unbracketed),
            place: publication?.first("a").flatMap(MARCRecord.unbracketed),
            publicationYear: publication?.first("d").flatMap(BookLookup.year(in:)),
            numberOfPages: record.first("215", "a").flatMap(MARCRecord.pages(in:)),
            isbn: isbn13,
            url: ark,
            tags: Array(record.fields("606").compactMap { $0.first("a") }.map(MARCRecord.clean).filter { !$0.isEmpty }.prefix(5))
        )
    }

    /// People from 700 and 701 (and 702) with the role author (070) or none given, else any
    /// person but a translator (730) or illustrator (440); failing that, the organizations in 710.
    static func authors(in record: MARCRecord) -> [AuthorName] {
        let people = record.fields("700") + record.fields("701") + record.fields("702")
        var chosen = people.filter { field in
            let roles = field.all("4")
            return roles.isEmpty || roles.contains("070")
        }
        if chosen.isEmpty { chosen = people.filter { Set($0.all("4")).isDisjoint(with: ["730", "440", "080"]) } }
        var names = chosen.compactMap { field -> AuthorName? in
            guard let family = field.first("a").map(MARCRecord.clean), !family.isEmpty else { return nil }
            return AuthorName(givenName: field.first("b").map(MARCRecord.clean) ?? "", familyName: family)
        }
        if names.isEmpty {
            names = (record.fields("710") + record.fields("711")).compactMap { $0.first("a") }
                .map { AuthorName(familyName: MARCRecord.clean($0)) }.filter { !$0.familyName.isEmpty }
        }
        return names
    }
}
