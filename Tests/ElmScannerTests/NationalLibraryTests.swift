// swiftlint:disable line_length   (catalogue answers written inline)
import XCTest
@testable import ElmScanner

/// The Deutsche Nationalbibliothek (MARC 21) and Bibliothèque nationale de France (UNIMARC) lookups.
final class NationalLibraryTests: XCTestCase {
    // MARK: Samples, shaped like the real answers

    private let dnbAnswer = """
    <?xml version="1.0" encoding="UTF-8"?><searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/"><version>1.1</version><numberOfRecords>2</numberOfRecords><records>
    <record><recordSchema>MARC21-xml</recordSchema><recordData><record xmlns="http://www.loc.gov/MARC21/slim" type="Bibliographic">
      <leader>00000nam a2200000 c 4500</leader>
      <controlfield tag="001">1131174790</controlfield>
      <datafield tag="020" ind1=" " ind2=" "><subfield code="a">9780000000002</subfield></datafield>
      <datafield tag="245" ind1="1" ind2="0"><subfield code="a">Another book</subfield></datafield>
    </record></recordData></record>
    <record><recordSchema>MARC21-xml</recordSchema><recordData><record xmlns="http://www.loc.gov/MARC21/slim" type="Bibliographic">
      <leader>00000nam a2200000 c 4500</leader>
      <controlfield tag="001">1131174791</controlfield>
      <datafield tag="020" ind1=" " ind2=" "><subfield code="a">9783257069709</subfield><subfield code="c">Festeinband</subfield></datafield>
      <datafield tag="100" ind1="1" ind2=" "><subfield code="a">Suter, Martin</subfield><subfield code="d">1948-</subfield><subfield code="e">Verfasser</subfield><subfield code="4">aut</subfield></datafield>
      <datafield tag="245" ind1="1" ind2="0"><subfield code="a">&lt;&lt;Der&gt;&gt; Elefant</subfield><subfield code="b">Roman</subfield><subfield code="c">Martin Suter</subfield></datafield>
      <datafield tag="264" ind1=" " ind2="1"><subfield code="a">Zürich</subfield><subfield code="b">Diogenes</subfield><subfield code="c">[2017]</subfield></datafield>
      <datafield tag="300" ind1=" " ind2=" "><subfield code="a">351 Seiten</subfield><subfield code="c">19 cm</subfield></datafield>
      <datafield tag="650" ind1=" " ind2="7"><subfield code="a">Gentechnologie</subfield></datafield>
      <datafield tag="700" ind1="1" ind2=" "><subfield code="a">Übersetzer, Uwe</subfield><subfield code="4">trl</subfield></datafield>
    </record></recordData></record></records></searchRetrieveResponse>
    """

    private let bnfAnswer = """
    <?xml version="1.0" encoding="UTF-8"?><srw:searchRetrieveResponse xmlns:srw="http://www.loc.gov/zing/srw/" xmlns:mxc="http://catalogue.bnf.fr/namespaces/InterXMarc"><srw:version>1.2</srw:version><srw:numberOfRecords>1</srw:numberOfRecords><srw:records><srw:record><srw:recordData>
    <mxc:record format="Unimarc" type="Bibliographic">
      <mxc:leader>00000nam0 2200000   450 </mxc:leader>
      <mxc:controlfield tag="001">FRBNF444747870000009</mxc:controlfield>
      <mxc:controlfield tag="003">http://catalogue.bnf.fr/ark:/12148/cb44474787d</mxc:controlfield>
      <mxc:datafield tag="010" ind1=" " ind2=" "><mxc:subfield code="a">978-2-226-25701-7</mxc:subfield><mxc:subfield code="b">br.</mxc:subfield></mxc:datafield>
      <mxc:datafield tag="073" ind1=" " ind2="0"><mxc:subfield code="a">9782226257017</mxc:subfield></mxc:datafield>
      <mxc:datafield tag="200" ind1="1" ind2=" "><mxc:subfield code="a">\u{0098}Le\u{009C} Sapiens</mxc:subfield><mxc:subfield code="b">Texte imprimé</mxc:subfield><mxc:subfield code="e">une brève histoire de l'humanité</mxc:subfield><mxc:subfield code="f">Yuval Noah Harari</mxc:subfield></mxc:datafield>
      <mxc:datafield tag="210" ind1=" " ind2=" "><mxc:subfield code="a">Paris</mxc:subfield><mxc:subfield code="c">Albin Michel</mxc:subfield><mxc:subfield code="d">DL 2015</mxc:subfield></mxc:datafield>
      <mxc:datafield tag="215" ind1=" " ind2=" "><mxc:subfield code="a">1 volume 512 p</mxc:subfield><mxc:subfield code="d">24 cm</mxc:subfield></mxc:datafield>
      <mxc:datafield tag="606" ind1=" " ind2=" "><mxc:subfield code="a">Civilisation -- Histoire</mxc:subfield></mxc:datafield>
      <mxc:datafield tag="700" ind1=" " ind2="|"><mxc:subfield code="a">Harari</mxc:subfield><mxc:subfield code="b">Yuval Noah</mxc:subfield><mxc:subfield code="f">1976-</mxc:subfield><mxc:subfield code="4">070</mxc:subfield></mxc:datafield>
      <mxc:datafield tag="702" ind1=" " ind2="|"><mxc:subfield code="a">Dauzat</mxc:subfield><mxc:subfield code="b">Pierre-Emmanuel</mxc:subfield><mxc:subfield code="4">730</mxc:subfield></mxc:datafield>
    </mxc:record></srw:recordData></srw:record></srw:records></srw:searchRetrieveResponse>
    """

    /// An old record found by ISBN-10 that holds no ISBN of its own, as the BnF has for some books.
    private let bnfOldRecord = """
    <srw:searchRetrieveResponse xmlns:srw="http://www.loc.gov/zing/srw/" xmlns:mxc="http://catalogue.bnf.fr/namespaces/InterXMarc"><srw:records><srw:record><srw:recordData>
    <mxc:record><mxc:controlfield tag="003">http://catalogue.bnf.fr/ark:/12148/cb35224436w</mxc:controlfield>
      <mxc:datafield tag="200" ind1="1" ind2=" "><mxc:subfield code="a">L'Étranger</mxc:subfield><mxc:subfield code="f">Albert Camus</mxc:subfield></mxc:datafield>
      <mxc:datafield tag="210" ind1=" " ind2=" "><mxc:subfield code="a">[Paris]</mxc:subfield><mxc:subfield code="c">Gallimard</mxc:subfield><mxc:subfield code="d">1971</mxc:subfield></mxc:datafield>
      <mxc:datafield tag="700" ind1=" " ind2="|"><mxc:subfield code="a">Camus</mxc:subfield><mxc:subfield code="b">Albert</mxc:subfield><mxc:subfield code="4">070</mxc:subfield></mxc:datafield>
    </mxc:record></srw:recordData></srw:record></srw:records></srw:searchRetrieveResponse>
    """

    /// Three printings under one ISBN, as the BNE holds them (2005 comes second, 2007 last), and a translator.
    private let bneAnswer = """
    <?xml version="1.0" encoding="UTF-8"?><searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/"><version>1.2</version><numberOfRecords>3</numberOfRecords><records>
    <record><recordData><record xmlns="http://www.loc.gov/MARC21/slim">
      <datafield ind1=" " ind2=" " tag="020"><subfield code="a">84-376-0494-X</subfield></datafield>
      <datafield ind1="1" ind2=" " tag="100"><subfield code="a">García Márquez, Gabriel</subfield><subfield code="d">1927-2014</subfield></datafield>
      <datafield ind1="1" ind2="0" tag="245"><subfield code="a">Cien años de soledad /</subfield><subfield code="c">Gabriel García Márquez</subfield></datafield>
      <datafield ind1=" " ind2=" " tag="260"><subfield code="a">Madrid :</subfield><subfield code="b">Cátedra,</subfield><subfield code="c">1984</subfield></datafield>
      <datafield ind1=" " ind2=" " tag="300"><subfield code="a">493 p. :</subfield><subfield code="b">il. ;</subfield><subfield code="c">18 cm</subfield></datafield>
    </record></recordData></record>
    <record><recordData><record xmlns="http://www.loc.gov/MARC21/slim">
      <datafield ind1=" " ind2=" " tag="020"><subfield code="a">84-376-0494-X</subfield></datafield>
      <datafield ind1="1" ind2=" " tag="100"><subfield code="a">García Márquez, Gabriel</subfield></datafield>
      <datafield ind1="1" ind2="0" tag="245"><subfield code="a">Cien años de soledad</subfield><subfield code="h">[Texto impreso]</subfield><subfield code="c">Gabriel García Márquez ; edición de Jacques Joset</subfield></datafield>
      <datafield ind1=" " ind2=" " tag="260"><subfield code="a">[S.l.]</subfield><subfield code="b">Cátedra</subfield><subfield code="c">[2007]</subfield></datafield>
      <datafield ind1=" " ind2=" " tag="300"><subfield code="a">550 p.</subfield></datafield>
      <datafield ind1="1" ind2=" " tag="700"><subfield code="a">Joset, Jacques</subfield><subfield code="d">1943-</subfield></datafield>
      <datafield ind1="1" ind2=" " tag="700"><subfield code="a">Rabassa, Gregory</subfield><subfield code="e">tr.</subfield></datafield>
    </record></recordData></record>
    <record><recordData><record xmlns="http://www.loc.gov/MARC21/slim">
      <datafield ind1=" " ind2=" " tag="020"><subfield code="a">9788437600000</subfield></datafield>
      <datafield ind1="1" ind2="0" tag="245"><subfield code="a">A different book</subfield></datafield>
      <datafield ind1=" " ind2=" " tag="260"><subfield code="c">2020</subfield></datafield>
    </record></recordData></record></records></searchRetrieveResponse>
    """

    // MARK: Parsing

    func testGermanRecordIsParsedAndTheRightEditionPicked() throws {
        let book = try XCTUnwrap(DNB.parse(Data(dnbAnswer.utf8), isbn13: "9783257069709"))
        XCTAssertEqual(book.title, "Der Elefant", "the <<non-sorting>> marks are removed")
        XCTAssertEqual(book.subtitle, "Roman")
        XCTAssertEqual(book.authors, [AuthorName(givenName: "Martin", familyName: "Suter")], "the translator is left out")
        XCTAssertEqual(book.publisher, "Diogenes")
        XCTAssertEqual(book.place, "Zürich")
        XCTAssertEqual(book.publicationYear, 2017)
        XCTAssertEqual(book.numberOfPages, "351")
        XCTAssertEqual(book.url, "https://d-nb.info/1131174791")
        XCTAssertEqual(book.tags, ["Gentechnologie"])
        XCTAssertEqual(book.isbn, "9783257069709")
    }

    func testGermanAnswerWithoutThatISBNIsNotFound() {
        XCTAssertNil(DNB.parse(Data(dnbAnswer.utf8), isbn13: "9783161484100"))
        XCTAssertNil(DNB.parse(Data("<searchRetrieveResponse><numberOfRecords>0</numberOfRecords></searchRetrieveResponse>".utf8), isbn13: "9783257069709"))
        XCTAssertNil(DNB.parse(Data("not xml".utf8), isbn13: "9783257069709"))
    }

    func testFrenchRecordIsParsed() throws {
        let book = try XCTUnwrap(BnF.parse(Data(bnfAnswer.utf8), isbn13: "9782226257017"))
        XCTAssertEqual(book.title, "Le Sapiens", "the invisible non-sorting marks are removed")
        XCTAssertEqual(book.subtitle, "une brève histoire de l'humanité")
        XCTAssertEqual(book.authors, [AuthorName(givenName: "Yuval Noah", familyName: "Harari")], "the translator is left out")
        XCTAssertEqual(book.publisher, "Albin Michel")
        XCTAssertEqual(book.place, "Paris")
        XCTAssertEqual(book.publicationYear, 2015)
        XCTAssertEqual(book.numberOfPages, "512")
        XCTAssertEqual(book.url, "https://catalogue.bnf.fr/ark:/12148/cb44474787d")
        XCTAssertEqual(book.tags, ["Civilisation -- Histoire"])
    }

    func testFrenchRecordWithNoISBNInsideIsTrustedButAWrongOneIsNot() throws {
        let old = try XCTUnwrap(BnF.parse(Data(bnfOldRecord.utf8), isbn13: "9782070360024"))
        XCTAssertEqual(old.title, "L'Étranger")
        XCTAssertEqual(old.place, "Paris", "square brackets are removed")
        XCTAssertEqual(old.publisher, "Gallimard")
        XCTAssertEqual(old.publicationYear, 1971)
        // A record that names other ISBNs is not this book.
        XCTAssertNil(BnF.parse(Data(bnfAnswer.utf8), isbn13: "9782070360024"))
    }

    func testSpanishRecordTakesTheLatestPrintingOfThatISBNAndOnlyTheAuthor() throws {
        let book = try XCTUnwrap(BNE.parse(Data(bneAnswer.utf8), isbn13: "9788437604947"))
        XCTAssertEqual(book.title, "Cien años de soledad")
        XCTAssertEqual(book.publicationYear, 2007, "the most recent of the printings that share the ISBN")
        XCTAssertEqual(book.publisher, "Cátedra")
        XCTAssertNil(book.place, "[S.l.] is a placeholder")
        XCTAssertEqual(book.numberOfPages, "550")
        XCTAssertEqual(book.authors, [AuthorName(givenName: "Gabriel", familyName: "García Márquez")], "editors and translators are left out")
        XCTAssertNil(BNE.parse(Data(bneAnswer.utf8), isbn13: "9788437609999"))
        XCTAssertTrue(BNE.isSpanish(isbn13: "9788437604947"))
        XCTAssertFalse(BNE.isSpanish(isbn13: "9788804668282"))
        XCTAssertTrue(BNE.url(isbn13: "9788437604947").absoluteString.contains("alma.isbn%3D9788437604947")
                      || BNE.url(isbn13: "9788437604947").absoluteString.contains("alma.isbn=9788437604947"))
    }

    func testOnlyTheBnFRecordCarriesAnAttributionNote() async throws {
        let isoDay = Date.now.formatted(.iso8601.year().month().day())
        StubProtocol.handler = { [bnfAnswer] request in
            request.url?.host == "catalogue.bnf.fr" ? (200, bnfAnswer) : (200, "{}")
        }
        let french = try await makeService().lookup(isbn: "9782226257017")
        XCTAssertEqual(french?.note, "Source: Bibliothèque nationale de France (catalogue.bnf.fr), Licence Ouverte, retrieved \(isoDay)")
        StubProtocol.reset()
        StubProtocol.handler = { [dnbAnswer] request in
            request.url?.host == "services.dnb.de" ? (200, dnbAnswer) : (200, "{}")
        }
        let german = try await makeService().lookup(isbn: "9783257069709")
        XCTAssertNil(german?.note)
    }

    func testNoteIsExportedWhereTheFormatHasAPlaceForIt() throws {
        var book = try XCTUnwrap(DNB.parse(Data(dnbAnswer.utf8), isbn13: "9783257069709"))
        book.note = "Source: test"
        XCTAssertTrue(ExportService.ris([book]).contains("N1  - Source: test"))
        XCTAssertTrue(ExportService.bibtex([book]).contains("note = {Source: test}"))
        XCTAssertTrue(String(decoding: try ExportService.cslJSON([book]), as: UTF8.self).contains("\"note\" : \"Source: test\""))
        XCTAssertTrue(ExportService.marcxml([book]).contains("tag=\"500\""))
        XCTAssertTrue(CSVFile.create([book]).starts(with: Data("\u{FEFF}Title,".utf8)))
        XCTAssertEqual(XLSX.values(for: book).last, "Source: test")
        XCTAssertEqual(XLSX.headers.last, "Note")
    }

    func testSpanishISBNGoesToTheBNEFirst() async throws {
        StubProtocol.handler = { [bneAnswer] request in
            request.url?.host == "catalogo.bne.es" ? (200, bneAnswer) : (200, "{}")
        }
        let book = try await makeService().lookup(isbn: "9788437604947")
        XCTAssertEqual(book?.publicationYear, 2007)
        XCTAssertEqual(StubProtocol.requests.map { $0.url?.host }, ["catalogo.bne.es"])
        XCTAssertNil(book?.note)
    }

    func testUnknownPlaceAndPublisherPlaceholdersAreDropped() {
        for text in ["[S.l.]", "[s.n.]", "[Erscheinungsort nicht ermittelbar]", "[Verlag nicht ermittelbar]"] {
            XCTAssertNil(MARCRecord.unbracketed(text), text)
        }
        XCTAssertEqual(MARCRecord.unbracketed("[Paris] :"), "Paris")
        XCTAssertEqual(MARCRecord.clean("Titel /"), "Titel")
        XCTAssertEqual(MARCRecord.clean("Der Titel ="), "Der Titel")
        XCTAssertEqual(MARCRecord.pages(in: "XII, 300 S."), "300")
        XCTAssertEqual(MARCRecord.pages(in: "1 volume 191 p"), "191")
    }

    func testOrganizationsAreUsedWhenThereAreNoPeople() throws {
        let xml = """
        <searchRetrieveResponse xmlns="x"><records><record><recordData><record xmlns="http://www.loc.gov/MARC21/slim">
        <datafield tag="020"><subfield code="a">9783257069709</subfield></datafield>
        <datafield tag="245"><subfield code="a">Jahresbericht</subfield></datafield>
        <datafield tag="710"><subfield code="a">Statistisches Bundesamt</subfield></datafield>
        </record></recordData></record></records></searchRetrieveResponse>
        """
        let book = try XCTUnwrap(DNB.parse(Data(xml.utf8), isbn13: "9783257069709"))
        XCTAssertEqual(book.authors, [AuthorName(familyName: "Statistisches Bundesamt")])
    }

    // MARK: Requests

    func testISBN10Conversion() {
        XCTAssertEqual(ISBN.isbn10(fromISBN13: "9780441172719"), "0441172717")
        XCTAssertEqual(ISBN.isbn10(fromISBN13: "9784003101018"), "4003101014")
        XCTAssertEqual(ISBN.isbn10(fromISBN13: "9788804668282"), "8804668288")
        XCTAssertNil(ISBN.isbn10(fromISBN13: "9791032300008"), "979 books have no ISBN-10")
        XCTAssertNil(ISBN.isbn10(fromISBN13: "123"))
    }

    func testRequestsAskForBothISBNForms() {
        let dnb = DNB.url(isbn13: "9783150091975").absoluteString
        XCTAssertTrue(dnb.hasPrefix("https://services.dnb.de/sru/dnb?"), dnb)
        XCTAssertTrue(dnb.contains("num=9783150091975%20or%20num=3150091977") || dnb.contains("num%3D9783150091975"), dnb)
        let bnf = BnF.url(isbn13: "9782070360024").absoluteString
        XCTAssertTrue(bnf.hasPrefix("https://catalogue.bnf.fr/api/SRU?"), bnf)
        XCTAssertTrue(bnf.contains("9782070360024%20") || bnf.contains("9782070360024 "), bnf)
        XCTAssertTrue(DNB.isGerman(isbn13: "9783150091975"))
        XCTAssertFalse(DNB.isGerman(isbn13: "9782070360024"))
        XCTAssertTrue(BnF.isFrench(isbn13: "9782070360024"))
        XCTAssertTrue(BnF.isFrench(isbn13: "9791032300008"))
        XCTAssertFalse(BnF.isFrench(isbn13: "9791190000000"))
    }

    // MARK: Order of lookup

    private func makeService() -> OpenLibraryBookLookupService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let fast = RateLimiter(maxRequests: 1000, perSeconds: 1)
        return OpenLibraryBookLookupService(
            session: URLSession(configuration: config), limiter: fast, ndlLimiter: fast,
            dnbLimiter: fast, bnfLimiter: fast, bneLimiter: fast, retryDelay: 0, contact: { "reader@example.com" })
    }

    override func setUp() { StubProtocol.reset() }

    func testGermanISBNGoesToTheDNBFirstWithoutTheUsersAddress() async throws {
        StubProtocol.handler = { [dnbAnswer] request in
            request.url?.host == "services.dnb.de" ? (200, dnbAnswer) : (200, "{}")
        }
        let book = try await makeService().lookup(isbn: "9783257069709")
        XCTAssertEqual(book?.title, "Der Elefant")
        XCTAssertEqual(StubProtocol.requests.map { $0.url?.host }, ["services.dnb.de"])
        let agent = StubProtocol.requests[0].value(forHTTPHeaderField: "User-Agent") ?? ""
        XCTAssertFalse(agent.contains("reader@example.com"), agent)
    }

    func testFrenchISBNGoesToTheBnFFirst() async throws {
        StubProtocol.handler = { [bnfAnswer] request in
            request.url?.host == "catalogue.bnf.fr" ? (200, bnfAnswer) : (200, "{}")
        }
        let book = try await makeService().lookup(isbn: "9782226257017")
        XCTAssertEqual(book?.publisher, "Albin Michel")
        XCTAssertEqual(StubProtocol.requests.map { $0.url?.host }, ["catalogue.bnf.fr"])
    }

    func testGermanBookTheDNBDoesNotKnowFallsBackToOpenLibrary() async throws {
        let json = #"{"ISBN:9783257069709":{"title":"Elefant","authors":[{"name":"Martin Suter"}]}}"#
        StubProtocol.handler = { request in
            request.url?.host == "openlibrary.org" ? (200, json) : (200, "<searchRetrieveResponse><numberOfRecords>0</numberOfRecords></searchRetrieveResponse>")
        }
        let book = try await makeService().lookup(isbn: "9783257069709")
        XCTAssertEqual(book?.title, "Elefant")
        XCTAssertEqual(StubProtocol.requests.map { $0.url?.host }, ["services.dnb.de", "openlibrary.org"])
    }

    func testEnglishISBNNeverAsksTheGermanOrFrenchLibraries() async throws {
        StubProtocol.handler = { _ in (200, #"{"ISBN:9780441172719":{"title":"Dune"}}"#) }
        _ = try await makeService().lookup(isbn: "9780441172719")
        XCTAssertEqual(StubProtocol.requests.map { $0.url?.host }, ["openlibrary.org"])
    }

    func testBnFOutageIsAnErrorNotACachedNotFound() async throws {
        StubProtocol.handler = { request in request.url?.host == "catalogue.bnf.fr" ? (503, "") : (200, "{}") }
        let service = makeService()
        do {
            _ = try await service.lookup(isbn: "9782226257017")
            XCTFail("expected a network error")
        } catch {}
    }
}
