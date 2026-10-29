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
}
