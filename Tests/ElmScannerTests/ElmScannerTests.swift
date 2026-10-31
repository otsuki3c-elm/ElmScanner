import XCTest
@testable import ElmScanner

final class ElmScannerTests: XCTestCase {
    private let dune = BookMetadata(
        title: "Dune", subtitle: nil, authors: [AuthorName(parsing: "Frank Herbert")],
        publisher: "Ace", place: nil, publicationYear: 2019, numberOfPages: "592",
        isbn: "9780441172719", url: nil, tags: ["Science fiction"])

    func testISBNCheckDigit() {
        XCTAssertEqual(ISBNBarcode.isbn(fromPayload: "9780441172719"), "9780441172719")
        XCTAssertNil(ISBNBarcode.isbn(fromPayload: "9780441172718"))
        XCTAssertNil(ISBNBarcode.isbn(fromPayload: "5012345678900"))
    }

    func testNormalizedISBN() {
        XCTAssertEqual(BookLookup.normalizedISBN("978-0-441-17271-9"), "9780441172719")
        XCTAssertNil(BookLookup.normalizedISBN("12345"))
    }

    func testParse() {
        let json = #"{"ISBN:9780441172719":{"title":"Dune","authors":[{"name":"Frank Herbert"}],"publish_date":"June 2, 2019","publishers":[{"name":"Ace"}]}}"#
        let book = BookLookup.parse(Data(json.utf8), isbn: "9780441172719")
        XCTAssertEqual(book?.title, "Dune")
        XCTAssertEqual(book?.authors, [AuthorName(givenName: "Frank", familyName: "Herbert")])
        XCTAssertEqual(book?.publicationYear, 2019)
    }

    func testBibTeX() {
        let text = ExportService.bibtex([dune, dune])
        XCTAssertTrue(text.contains("@book{herbert2019dune,"))
        XCTAssertTrue(text.contains("@book{herbert2019dunea,"))
        XCTAssertTrue(text.contains("author = {Herbert, Frank}"))
    }

    func testCSL() throws {
        let data = try ExportService.cslJSON([dune])
        let items = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(items.first?["type"] as? String, "book")
        XCTAssertEqual(items.first?["ISBN"] as? String, "9780441172719")
    }

    @MainActor
    func testUnexportedBooksSurviveARestart() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "ElmScannerTests-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        ScanStore.save([
            ScannedBook(isbn: dune.isbn, state: .found(dune)),
            ScannedBook(isbn: "9780857073006", state: .failed("offline")),
        ], to: url)

        let session = ScanSession(storeURL: url)
        XCTAssertEqual(session.books.map(\.isbn), [dune.isbn, "9780857073006"])
        XCTAssertEqual(session.books[0].metadata, dune)

        session.markExported()
        XCTAssertEqual(ScanSession(storeURL: url).books.map(\.isbn), ["9780857073006"])

        session.removeAll()
        XCTAssertTrue(ScanSession(storeURL: url).books.isEmpty)
    }

    func testEveryFormatProducesWellFormedOutput() throws {
        let org = BookMetadata(
            title: "Active ageing", subtitle: "a portrait & more", authors: [AuthorName(familyName: "Eurostat")],
            publisher: "Publications <Office>", place: "Luxembourg", publicationYear: 2012, numberOfPages: "141",
            isbn: "9789279215070", url: "http://example.org/?a=1&b=2", tags: ["Aging"])
        for format in ExportService.Format.allCases {
            let data = try ExportService.data(for: [dune, org], format: format)
            XCTAssertFalse(data.isEmpty, format.title)
            if format.mimeType.hasSuffix("xml") {
                let parser = XMLParser(data: data)
                XCTAssertTrue(parser.parse(), "\(format.title) isn't well-formed XML: \(String(describing: parser.parserError))")
            }
        }
    }

    func testBinaryMARCRecordsAreSelfConsistent() throws {
        let data = try ExportService.data(for: [dune, dune], format: .marc)
        var offset = 0
        var records = 0
        while offset < data.count {
            let length = Int(String(decoding: data[offset..<offset + 5], as: UTF8.self))!
            XCTAssertEqual(data[offset + length - 1], 0x1D)
            let base = Int(String(decoding: data[offset + 12..<offset + 17], as: UTF8.self))!
            XCTAssertEqual(data[offset + base - 1], 0x1E)
            // Every directory entry points at a field that ends with the field terminator.
            var entry = offset + 24
            while data[entry] != 0x1E {
                let size = Int(String(decoding: data[entry + 3..<entry + 7], as: UTF8.self))!
                let start = Int(String(decoding: data[entry + 7..<entry + 12], as: UTF8.self))!
                XCTAssertEqual(data[offset + base + start + size - 1], 0x1E)
                entry += 12
            }
            offset += length
            records += 1
        }
        XCTAssertEqual(records, 2)
    }
}
