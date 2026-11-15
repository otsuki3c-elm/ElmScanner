import Foundation

/// Writers for the other formats Zotero imports. Each one is laid out the way
/// that format's Zotero importer reads a book.
extension ExportService {
    // MARK: Shared

    private static func xml(_ text: String) -> String {
        // Control characters other than tab and line breaks aren't allowed in XML at all.
        String(String.UnicodeScalarView(text.unicodeScalars.filter { $0.value >= 0x20 || $0 == "\t" || $0 == "\n" || $0 == "\r" }))
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// "Family, Given", or just the name for an organization.
    private static func inverted(_ author: AuthorName) -> String {
        author.isOrganization ? author.familyName : "\(author.familyName), \(author.givenName)"
    }

    private static let xmlHeader = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"

    // MARK: BibLaTeX

    static func biblatex(_ books: [BookMetadata]) -> String {
        var usedKeys = Set<String>()
        return books.map { book in
            var fields: [(String, String)] = [("title", book.title)]
            if let subtitle = book.subtitle, !subtitle.isEmpty { fields.append(("subtitle", subtitle)) }
            if !book.authors.isEmpty { fields.append(("author", bibAuthors(book.authors))) }
            if let publisher = book.publisher { fields.append(("publisher", publisher)) }
            if let place = book.place { fields.append(("location", place)) }
            if let year = book.publicationYear { fields.append(("date", String(year))) }
            if let pages = book.numberOfPages { fields.append(("pagetotal", pages)) }
            fields.append(("isbn", book.isbn))
            if let url = book.url { fields.append(("url", url)) }
            if !book.tags.isEmpty { fields.append(("keywords", book.tags.joined(separator: ", "))) }
            let body = fields.map { key, value in "  \(key) = {\(key == "author" ? value : escape(value))}" }.joined(separator: ",\n")
            return "@book{\(citeKey(for: book, usedKeys: &usedKeys)),\n\(body)\n}"
        }.joined(separator: "\n\n") + "\n"
    }

    // MARK: RIS

    static func ris(_ books: [BookMetadata]) -> String {
        books.map { book in
            var lines = ["TY  - BOOK", "TI  - \(book.fullTitle)"]
            lines += book.authors.map { "AU  - \(inverted($0))" }
            if let publisher = book.publisher { lines.append("PB  - \(publisher)") }
            if let place = book.place { lines.append("CY  - \(place)") }
            if let year = book.publicationYear { lines.append("PY  - \(year)") }
            lines.append("SN  - \(book.isbn)")
            if let pages = book.numberOfPages { lines.append("SP  - \(pages)") }
            if let url = book.url { lines.append("UR  - \(url)") }
            lines += book.tags.map { "KW  - \($0)" }
            lines.append("ER  - ")
            return lines.joined(separator: "\r\n")
        }.joined(separator: "\r\n\r\n") + "\r\n"
    }

    // MARK: Refer/BibIX

    static func refer(_ books: [BookMetadata]) -> String {
        books.map { book in
            var lines = ["%0 Book", "%T \(book.fullTitle)"]
            lines += book.authors.map { "%A \(inverted($0))" }
            if let publisher = book.publisher { lines.append("%I \(publisher)") }
            if let place = book.place { lines.append("%C \(place)") }
            if let year = book.publicationYear { lines.append("%D \(year)") }
            lines.append("%@ \(book.isbn)")
            if let pages = book.numberOfPages { lines.append("%P \(pages)") }
            if let url = book.url { lines.append("%U \(url)") }
            lines += book.tags.map { "%K \($0)" }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n") + "\n"
    }

    // MARK: RefWorks Tagged

    static func refworks(_ books: [BookMetadata]) -> String {
        books.enumerated().map { index, book in
            var lines = ["RT Book, Whole", "SR Print(0)", "ID \(index + 1)", "T1 \(book.fullTitle)"]
            lines += book.authors.map { "A1 \(inverted($0))" }
            if let publisher = book.publisher { lines.append("PB \(publisher)") }
            if let place = book.place { lines.append("PP \(place)") }
            if let year = book.publicationYear { lines.append("YR \(year)") }
            lines.append("SN \(book.isbn)")
            if let pages = book.numberOfPages { lines.append("SP \(pages)") }
            if let url = book.url { lines.append("UL \(url)") }
            lines += book.tags.map { "K1 \($0)" }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n") + "\n"
    }

    // MARK: Web of Science Tagged

    static func webOfScience(_ books: [BookMetadata]) -> String {
        let records = books.map { book -> String in
            var lines = ["PT B"]
            for (index, author) in book.authors.enumerated() {
                lines.append((index == 0 ? "AU " : "   ") + inverted(author))
            }
            lines.append("TI \(book.fullTitle)")
            if let publisher = book.publisher { lines.append("PU \(publisher)") }
            if let place = book.place { lines.append("PI \(place)") }
            if let year = book.publicationYear { lines.append("PY \(year)") }
            if let pages = book.numberOfPages { lines.append("PG \(pages)") }
            lines.append("BN \(book.isbn)")
            lines.append("ER")
            return lines.joined(separator: "\n")
        }
        return (["FN Clarivate Analytics Web of Science", "VR 1.0"] + [records.joined(separator: "\n\n")] + ["", "EF"])
            .joined(separator: "\n") + "\n"
    }

    // MARK: MODS

    static func mods(_ books: [BookMetadata]) -> String {
        let items = books.map { book -> String in
            var out = "  <mods version=\"3.4\">\n    <titleInfo>\n      <title>\(xml(book.title))</title>\n"
            if let subtitle = book.subtitle, !subtitle.isEmpty { out += "      <subTitle>\(xml(subtitle))</subTitle>\n" }
            out += "    </titleInfo>\n"
            for author in book.authors {
                out += "    <name type=\"\(author.isOrganization ? "corporate" : "personal")\">\n"
                if author.isOrganization {
                    out += "      <namePart>\(xml(author.familyName))</namePart>\n"
                } else {
                    out += "      <namePart type=\"family\">\(xml(author.familyName))</namePart>\n"
                    out += "      <namePart type=\"given\">\(xml(author.givenName))</namePart>\n"
                }
                out += "      <role><roleTerm type=\"text\">author</roleTerm></role>\n    </name>\n"
            }
            out += "    <typeOfResource>text</typeOfResource>\n    <genre authority=\"marcgt\">book</genre>\n    <originInfo>\n"
            if let place = book.place { out += "      <place><placeTerm type=\"text\">\(xml(place))</placeTerm></place>\n" }
            if let publisher = book.publisher { out += "      <publisher>\(xml(publisher))</publisher>\n" }
            if let year = book.publicationYear { out += "      <dateIssued>\(year)</dateIssued>\n" }
            out += "      <issuance>monographic</issuance>\n    </originInfo>\n"
            if let pages = book.numberOfPages {
                out += "    <physicalDescription><extent>\(xml(pages)) p.</extent></physicalDescription>\n"
            }
            for tag in book.tags { out += "    <subject><topic>\(xml(tag))</topic></subject>\n" }
            out += "    <identifier type=\"isbn\">\(xml(book.isbn))</identifier>\n"
            if let url = book.url { out += "    <location><url>\(xml(url))</url></location>\n" }
            return out + "  </mods>\n"
        }
        return xmlHeader + "<modsCollection xmlns=\"http://www.loc.gov/mods/v3\">\n" + items.joined() + "</modsCollection>\n"
    }

    // MARK: MARC (shared by MARCXML and binary MARC)

    private enum MARCField {
        case control(tag: String, value: String)
        case data(tag: String, ind1: Character, ind2: Character, subfields: [(code: Character, value: String)])
    }

    private static func marcFields(_ book: BookMetadata) -> [MARCField] {
        var fields: [MARCField] = [
            .control(tag: "001", value: book.isbn),
            .data(tag: "020", ind1: " ", ind2: " ", subfields: [("a", book.isbn)]),
        ]
        for (index, author) in book.authors.enumerated() {
            let main = index == 0
            if author.isOrganization {
                fields.append(.data(tag: main ? "110" : "710", ind1: "2", ind2: " ", subfields: [("a", author.familyName)]))
            } else {
                fields.append(.data(tag: main ? "100" : "700", ind1: "1", ind2: " ", subfields: [("a", inverted(author))]))
            }
        }
        var title: [(code: Character, value: String)] = [("a", book.title)]
        if let subtitle = book.subtitle, !subtitle.isEmpty {
            title = [("a", book.title + " :"), ("b", subtitle)]
        }
        fields.append(.data(tag: "245", ind1: book.authors.isEmpty ? "0" : "1", ind2: "0", subfields: title))
        var imprint: [(code: Character, value: String)] = []
        if let place = book.place { imprint.append(("a", book.publisher == nil ? place : place + " :")) }
        if let publisher = book.publisher { imprint.append(("b", book.publicationYear == nil ? publisher : publisher + ",")) }
        if let year = book.publicationYear { imprint.append(("c", "\(year).")) }
        if !imprint.isEmpty { fields.append(.data(tag: "260", ind1: " ", ind2: " ", subfields: imprint)) }
        if let pages = book.numberOfPages {
            fields.append(.data(tag: "300", ind1: " ", ind2: " ", subfields: [("a", pages.allSatisfy(\.isNumber) ? "\(pages) p." : pages)]))
        }
        for tag in book.tags { fields.append(.data(tag: "650", ind1: " ", ind2: "0", subfields: [("a", tag + ".")])) }
        if let url = book.url { fields.append(.data(tag: "856", ind1: "4", ind2: "0", subfields: [("u", url)])) }
        return fields
    }

    static func marcxml(_ books: [BookMetadata]) -> String {
        let records = books.map { book -> String in
            var out = "  <record>\n    <leader>00000nam a2200000 a 4500</leader>\n"
            for field in marcFields(book) {
                switch field {
                case .control(let tag, let value):
                    out += "    <controlfield tag=\"\(tag)\">\(xml(value))</controlfield>\n"
                case .data(let tag, let ind1, let ind2, let subfields):
                    out += "    <datafield tag=\"\(tag)\" ind1=\"\(ind1)\" ind2=\"\(ind2)\">\n"
                    for sub in subfields { out += "      <subfield code=\"\(sub.code)\">\(xml(sub.value))</subfield>\n" }
                    out += "    </datafield>\n"
                }
            }
            return out + "  </record>\n"
        }
        return xmlHeader + "<collection xmlns=\"http://www.loc.gov/MARC21/slim\">\n" + records.joined() + "</collection>\n"
    }

    /// ISO 2709 records: a 24-byte leader, a directory, then the fields (UTF-8).
    static func marc(_ books: [BookMetadata]) -> Data {
        let fieldEnd: UInt8 = 0x1E, recordEnd: UInt8 = 0x1D, subfieldMark: UInt8 = 0x1F
        var output = Data()
        for book in books {
            var directory = Data(), body = Data()
            for field in marcFields(book) {
                var bytes = Data()
                let tag: String
                switch field {
                case .control(let fieldTag, let value):
                    tag = fieldTag
                    bytes.append(Data(value.utf8))
                case .data(let fieldTag, let ind1, let ind2, let subfields):
                    tag = fieldTag
                    bytes.append(Data("\(ind1)\(ind2)".utf8))
                    for sub in subfields {
                        bytes.append(subfieldMark)
                        bytes.append(Data("\(sub.code)\(sub.value)".utf8))
                    }
                }
                bytes.append(fieldEnd)
                directory.append(Data((tag + String(format: "%04d%05d", bytes.count, body.count)).utf8))
                body.append(bytes)
            }
            let base = 24 + directory.count + 1
            let total = base + body.count + 1
            output.append(Data((String(format: "%05d", total) + "nam a22" + String(format: "%05d", base) + " a 4500").utf8))
            output.append(directory)
            output.append(fieldEnd)
            output.append(body)
            output.append(recordEnd)
        }
        return output
    }

    // MARK: EndNote XML

    static func endnoteXML(_ books: [BookMetadata]) -> String {
        let records = books.enumerated().map { index, book -> String in
            var out = "    <record>\n      <rec-number>\(index + 1)</rec-number>\n      <ref-type name=\"Book\">6</ref-type>\n"
            if !book.authors.isEmpty {
                out += "      <contributors>\n        <authors>\n"
                for author in book.authors { out += "          <author>\(xml(inverted(author)))</author>\n" }
                out += "        </authors>\n      </contributors>\n"
            }
            out += "      <titles>\n        <title>\(xml(book.fullTitle))</title>\n      </titles>\n"
            if let pages = book.numberOfPages { out += "      <pages>\(xml(pages))</pages>\n" }
            if !book.tags.isEmpty {
                out += "      <keywords>\n" + book.tags.map { "        <keyword>\(xml($0))</keyword>\n" }.joined() + "      </keywords>\n"
            }
            if let year = book.publicationYear { out += "      <dates>\n        <year>\(year)</year>\n      </dates>\n" }
            if let place = book.place { out += "      <pub-location>\(xml(place))</pub-location>\n" }
            if let publisher = book.publisher { out += "      <publisher>\(xml(publisher))</publisher>\n" }
            out += "      <isbn>\(xml(book.isbn))</isbn>\n"
            if let url = book.url {
                out += "      <urls>\n        <related-urls>\n          <url>\(xml(url))</url>\n        </related-urls>\n      </urls>\n"
            }
            return out + "    </record>\n"
        }
        return xmlHeader + "<xml>\n  <records>\n" + records.joined() + "  </records>\n</xml>\n"
    }

    // MARK: RDF

    private static func rdfPerson(_ author: AuthorName) -> String {
        author.isOrganization
            ? "<foaf:Organization><foaf:name>\(xml(author.familyName))</foaf:name></foaf:Organization>"
            : "<foaf:Person><foaf:surname>\(xml(author.familyName))</foaf:surname><foaf:givenName>\(xml(author.givenName))</foaf:givenName></foaf:Person>"
    }

    static func zoteroRDF(_ books: [BookMetadata]) -> String {
        let items = books.map { book -> String in
            var out = "  <bib:Book rdf:about=\"urn:isbn:\(xml(book.isbn))\">\n    <z:itemType>book</z:itemType>\n"
            if book.publisher != nil || book.place != nil {
                out += "    <dc:publisher>\n      <foaf:Organization>\n"
                if let place = book.place {
                    out += "        <vcard:adr><vcard:Address><vcard:locality>\(xml(place))</vcard:locality></vcard:Address></vcard:adr>\n"
                }
                if let publisher = book.publisher { out += "        <foaf:name>\(xml(publisher))</foaf:name>\n" }
                out += "      </foaf:Organization>\n    </dc:publisher>\n"
            }
            if !book.authors.isEmpty {
                out += "    <bib:authors>\n      <rdf:Seq>\n"
                for author in book.authors { out += "        <rdf:li>\(rdfPerson(author))</rdf:li>\n" }
                out += "      </rdf:Seq>\n    </bib:authors>\n"
            }
            for tag in book.tags { out += "    <dc:subject>\(xml(tag))</dc:subject>\n" }
            out += "    <dc:title>\(xml(book.fullTitle))</dc:title>\n"
            if let year = book.publicationYear { out += "    <dc:date>\(year)</dc:date>\n" }
            if let pages = book.numberOfPages { out += "    <z:numPages>\(xml(pages))</z:numPages>\n" }
            if let url = book.url {
                out += "    <dc:identifier><dcterms:URI><rdf:value>\(xml(url))</rdf:value></dcterms:URI></dc:identifier>\n"
            }
            out += "    <dc:identifier>ISBN \(xml(book.isbn))</dc:identifier>\n"
            return out + "  </bib:Book>\n"
        }
        return xmlHeader + """
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:z="http://www.zotero.org/namespaces/export#" \
        xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dc="http://purl.org/dc/elements/1.1/" \
        xmlns:bib="http://purl.org/net/biblio#" xmlns:foaf="http://xmlns.com/foaf/0.1/" \
        xmlns:vcard="http://nwalsh.com/rdf/vCard#">

        """ + items.joined() + "</rdf:RDF>\n"
    }

    static func bibliontologyRDF(_ books: [BookMetadata]) -> String {
        let items = books.map { book -> String in
            var out = "  <bibo:Book rdf:about=\"urn:isbn:\(xml(book.isbn))\">\n    <dcterms:title>\(xml(book.fullTitle))</dcterms:title>\n"
            for author in book.authors { out += "    <dcterms:creator>\(rdfPerson(author))</dcterms:creator>\n" }
            if book.publisher != nil || book.place != nil {
                out += "    <dcterms:publisher>\n      <foaf:Organization>\n"
                if let publisher = book.publisher { out += "        <foaf:name>\(xml(publisher))</foaf:name>\n" }
                if let place = book.place { out += "        <address:localityName>\(xml(place))</address:localityName>\n" }
                out += "      </foaf:Organization>\n    </dcterms:publisher>\n"
            }
            if let year = book.publicationYear { out += "    <dcterms:date>\(year)</dcterms:date>\n" }
            out += "    <\(book.isbn.count == 10 ? "bibo:isbn10" : "bibo:isbn13")>\(xml(book.isbn))</\(book.isbn.count == 10 ? "bibo:isbn10" : "bibo:isbn13")>\n"
            if let pages = book.numberOfPages { out += "    <bibo:numPages>\(xml(pages))</bibo:numPages>\n" }
            if let url = book.url { out += "    <bibo:uri>\(xml(url))</bibo:uri>\n" }
            for tag in book.tags { out += "    <dcterms:subject>\(xml(tag))</dcterms:subject>\n" }
            return out + "  </bibo:Book>\n"
        }
        return xmlHeader + """
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:dcterms="http://purl.org/dc/terms/" \
        xmlns:bibo="http://purl.org/ontology/bibo/" xmlns:foaf="http://xmlns.com/foaf/0.1/" \
        xmlns:address="http://schemas.talis.com/2005/address/schema#">

        """ + items.joined() + "</rdf:RDF>\n"
    }

    static func dublinCoreRDF(_ books: [BookMetadata]) -> String {
        let items = books.map { book -> String in
            var out = "  <rdf:Description rdf:about=\"urn:isbn:\(xml(book.isbn))\">\n    <dc:type>book</dc:type>\n    <dc:title>\(xml(book.fullTitle))</dc:title>\n"
            for author in book.authors { out += "    <dc:creator>\(xml(inverted(author)))</dc:creator>\n" }
            if let publisher = book.publisher { out += "    <dc:publisher>\(xml(publisher))</dc:publisher>\n" }
            if let year = book.publicationYear { out += "    <dc:date>\(year)</dc:date>\n" }
            for tag in book.tags { out += "    <dc:subject>\(xml(tag))</dc:subject>\n" }
            out += "    <dc:identifier>ISBN \(xml(book.isbn))</dc:identifier>\n"
            if let url = book.url { out += "    <dc:identifier>\(xml(url))</dc:identifier>\n" }
            return out + "  </rdf:Description>\n"
        }
        return xmlHeader + """
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:dc="http://purl.org/dc/elements/1.1/">

        """ + items.joined() + "</rdf:RDF>\n"
    }

    // MARK: XML ContextObject

    static func contextObject(_ books: [BookMetadata]) -> String {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let objects = books.map { book -> String in
            var out = "  <ctx:context-object timestamp='\(stamp)' encoding='info:ofi/enc:UTF-8' version='Z39.88-2004' identifier=''>\n"
            out += "    <ctx:referent>\n      <ctx:metadata-by-val>\n        <ctx:format>info:ofi/fmt:xml:xsd:book</ctx:format>\n        <ctx:metadata>\n"
            out += "          <book xmlns:rft='info:ofi/fmt:xml:xsd:book'>\n"
            out += "            <rft:genre>book</rft:genre>\n            <rft:btitle>\(xml(book.fullTitle))</rft:btitle>\n"
            for author in book.authors {
                if author.isOrganization {
                    out += "            <rft:aucorp>\(xml(author.familyName))</rft:aucorp>\n"
                } else {
                    out += "            <rft:aulast>\(xml(author.familyName))</rft:aulast>\n            <rft:aufirst>\(xml(author.givenName))</rft:aufirst>\n"
                }
            }
            if let publisher = book.publisher { out += "            <rft:pub>\(xml(publisher))</rft:pub>\n" }
            if let place = book.place { out += "            <rft:place>\(xml(place))</rft:place>\n" }
            if let year = book.publicationYear { out += "            <rft:date>\(year)</rft:date>\n" }
            if let pages = book.numberOfPages { out += "            <rft:tpages>\(xml(pages))</rft:tpages>\n" }
            out += "            <rft:isbn>\(xml(book.isbn))</rft:isbn>\n          </book>\n"
            out += "        </ctx:metadata>\n      </ctx:metadata-by-val>\n    </ctx:referent>\n  </ctx:context-object>\n"
            return out
        }
        return "<ctx:context-objects xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:ctx='info:ofi/fmt:xml:xsd:ctx'>\n"
            + objects.joined() + "</ctx:context-objects>\n"
    }
}
