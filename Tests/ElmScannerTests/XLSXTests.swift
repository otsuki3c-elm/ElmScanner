// swiftlint:disable line_length   (workbook XML written inline)
import XCTest
@testable import ElmScanner

final class XLSXTests: XCTestCase {
    private let dune = BookMetadata(
        title: "Dune", subtitle: nil, authors: [AuthorName(givenName: "Frank", familyName: "Herbert")],
        publisher: "Ace", place: "New York", publicationYear: 1990, numberOfPages: "535",
        isbn: "9780441172719", url: nil, tags: ["SF"])
    private let wonder = BookMetadata(
        title: "Fish & <Chips>", subtitle: "A \"guide\"", authors: [AuthorName(familyName: "Eurostat")],
        publisher: nil, place: nil, publicationYear: nil, numberOfPages: nil,
        isbn: "9789279215070", url: nil, tags: [])

    private func sheetXML(_ file: Data) throws -> String {
        let entries = try ZipFile.read(file)
        let entry = try XCTUnwrap(entries.first { $0.name == "xl/worksheets/sheet1.xml" })
        return try XCTUnwrap(String(data: entry.contents(), encoding: .utf8))
    }

    func testNewWorkbookIsAValidZipOfWellFormedXML() throws {
        let file = try XLSX.create([dune, wonder])
        let entries = try ZipFile.read(file)
        XCTAssertEqual(entries.map(\.name).first, "[Content_Types].xml")
        for entry in entries {
            let parser = XMLParser(data: try entry.contents())
            XCTAssertTrue(parser.parse(), "\(entry.name): \(String(describing: parser.parserError))")
        }
        let sheet = try sheetXML(file)
        XCTAssertTrue(sheet.contains("Fish &amp; &lt;Chips&gt;"))
        XCTAssertTrue(sheet.contains("<c r=\"F2\"><v>1990</v></c>"))
        XCTAssertTrue(sheet.contains("<dimension ref=\"A1:J3\"/>"))
    }

    func testZipChecksumsMatch() throws {
        for entry in try ZipFile.read(try XLSX.create([dune])) {
            XCTAssertEqual(CRC32Check.checksum(try entry.contents()), entry.crc, entry.name)
        }
    }

    func testAppendAddsRowsAfterTheLastOne() throws {
        let first = try XLSX.create([dune])
        let result = try XLSX.append([wonder], to: first)
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.skipped, 0)
        let sheet = try sheetXML(result.data)
        XCTAssertTrue(sheet.contains("<row r=\"3\">"))
        XCTAssertTrue(sheet.contains("Fish &amp; &lt;Chips&gt;"))
        XCTAssertTrue(sheet.contains("<dimension ref=\"A1:J3\"/>"))
        // Still a readable workbook that can be added to again.
        let third = BookMetadata(title: "Third", subtitle: nil, authors: [], publisher: nil, place: nil,
                                 publicationYear: nil, numberOfPages: nil, isbn: "9780061120084", url: nil, tags: [])
        XCTAssertTrue(try sheetXML(XLSX.append([third], to: result.data).data).contains("<row r=\"4\">"))
    }

    func testBooksAlreadyInTheFileAreSkipped() throws {
        let first = try XLSX.create([dune])
        let result = try XLSX.append([dune, wonder], to: first)
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.skipped, 1)
        let again = try XLSX.append([dune], to: result.data)
        XCTAssertEqual(again.added, 0)
        XCTAssertEqual(again.data, result.data)
    }

    func testFollowsTheSheetsOwnColumnOrderAndSharedStrings() throws {
        // A workbook as Excel writes it: shared strings, columns in another order, other columns present.
        let sheet = """
        <?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:C2"/><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c></row><row r="2"><c r="A2" t="s"><v>3</v></c><c r="B2" t="s"><v>4</v></c><c r="C2"><v>5</v></c></row></sheetData></worksheet>
        """
        let strings = """
        <?xml version="1.0" encoding="UTF-8"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>ISBN</t></si><si><t>Notes</t></si><si><t>Title</t></si><si><t>978-0-441-17271-9</t></si><si><t>mine</t></si></sst>
        """
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let file = ZipFile.write([
            ZipFile.Entry(name: "xl/workbook.xml", content: Data("<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"\(rel)\"><sheets><sheet name=\"S\" sheetId=\"1\" r:id=\"rId9\"/></sheets></workbook>".utf8)),
            ZipFile.Entry(name: "xl/_rels/workbook.xml.rels", content: Data("<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId9\" Type=\"\(rel)/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>".utf8)),
            ZipFile.Entry(name: "xl/worksheets/sheet1.xml", content: Data(sheet.utf8)),
            ZipFile.Entry(name: "xl/sharedStrings.xml", content: Data(strings.utf8))
        ])
        let result = try XLSX.append([dune, wonder], to: file)
        XCTAssertEqual(result.skipped, 1, "Dune's ISBN is there, written with hyphens")
        let text = try sheetXML(result.data)
        XCTAssertTrue(text.contains("<c r=\"A3\" t=\"inlineStr\"><is><t xml:space=\"preserve\">9789279215070</t></is></c>"), text)
        XCTAssertTrue(text.contains("<c r=\"C3\" t=\"inlineStr\">"))
        XCTAssertFalse(text.contains("r=\"B3\""), "the Notes column is left empty")
        XCTAssertTrue(text.contains("<dimension ref=\"A1:C3\"/>"))
        XCTAssertEqual(try ZipFile.read(result.data).count, 4, "other parts are carried over")
    }

    func testRejectsFilesItCannotUse() {
        XCTAssertThrowsError(try XLSX.append([dune], to: Data("not a zip".utf8)))
        let plainZip = ZipFile.write([ZipFile.Entry(name: "readme.txt", content: Data("hi".utf8))])
        XCTAssertThrowsError(try XLSX.append([dune], to: plainZip))
    }

    func testSheetWithOtherColumnsOnlyIsRefused() throws {
        let sheet = "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>Name</t></is></c></row></sheetData></worksheet>"
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let file = ZipFile.write([
            ZipFile.Entry(name: "xl/workbook.xml", content: Data("<workbook xmlns:r=\"\(rel)\"><sheets><sheet name=\"S\" r:id=\"rId1\"/></sheets></workbook>".utf8)),
            ZipFile.Entry(name: "xl/_rels/workbook.xml.rels", content: Data("<Relationships><Relationship Id=\"rId1\" Target=\"worksheets/sheet1.xml\"/></Relationships>".utf8)),
            ZipFile.Entry(name: "xl/worksheets/sheet1.xml", content: Data(sheet.utf8))
        ])
        XCTAssertThrowsError(try XLSX.append([dune], to: file)) { XCTAssertEqual($0 as? XLSX.Failure, .noColumns) }
    }
}
