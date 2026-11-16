import XCTest
@testable import ElmScanner

final class CSVFileTests: XCTestCase {
    private let dune = BookMetadata(
        title: "Dune", subtitle: "Messiah, \"Part 2\"", authors: [AuthorName(givenName: "Frank", familyName: "Herbert")],
        publisher: "Ace", place: nil, publicationYear: 1990, numberOfPages: "535",
        isbn: "9780441172719", url: nil, tags: ["SF", "classic"])
    private let formula = BookMetadata(
        title: "=1+1", subtitle: nil, authors: [], publisher: nil, place: nil, publicationYear: nil,
        numberOfPages: nil, isbn: "9789279215070", url: nil, tags: [])

    private func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

    func testNewFileHasBOMHeaderQuotingAndFormulaGuard() throws {
        let csv = text(CSVFile.create([dune, formula]))
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}Title,Subtitle,Authors,"))
        let records = CSVFile.parse(String(csv.dropFirst()), delimiter: ",")
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[1][1], "Messiah, \"Part 2\"")
        XCTAssertEqual(records[1][2], "Herbert, Frank")
        XCTAssertEqual(records[1][9], "SF, classic")
        XCTAssertEqual(records[2][0], "'=1+1")
        XCTAssertEqual(records[1].count, XLSX.headers.count)
    }

    func testAppendKeepsTheOriginalBytesAndSkipsDuplicates() throws {
        let first = CSVFile.create([dune])
        let result = try CSVFile.append([dune, formula], to: first)
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.data.prefix(first.count), first)
        XCTAssertEqual(CSVFile.parse(String(text(result.data).dropFirst()), delimiter: ",").count, 3)
        XCTAssertEqual(try CSVFile.append([dune], to: result.data).added, 0)
    }

    func testFollowsTheFilesOwnColumnsDelimiterAndLineEndings() throws {
        // Semicolons, CRLF, no final line break, a quoted line break, hyphenated ISBN, extra column.
        let file = Data("Notes;ISBN;Title\r\n\"two\nlines\";978-0-441-17271-9;Old".utf8)
        let result = try CSVFile.append([dune, formula], to: file)
        XCTAssertEqual(result.skipped, 1)
        let records = CSVFile.parse(text(result.data), delimiter: ";")
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[1][0], "two\nlines")
        XCTAssertEqual(records[2], ["", "9789279215070", "'=1+1"])
        XCTAssertTrue(text(result.data).contains("Old\r\n"), "line break added before the new line, in the file's style")
    }

    func testEmptyFileGetsAHeader() throws {
        let result = try CSVFile.append([dune], to: Data())
        XCTAssertTrue(text(result.data).hasPrefix("\u{FEFF}Title,"))
        XCTAssertEqual(result.added, 1)
    }

    func testRefusesFilesItCannotUse() {
        XCTAssertThrowsError(try CSVFile.append([dune], to: Data("Name,Age\nA,1\n".utf8))) {
            XCTAssertEqual($0 as? CSVFile.Failure, .noColumns)
        }
        XCTAssertThrowsError(try CSVFile.append([dune], to: Data([0xFF, 0xFE, 0x00, 0x41, 0xC3]))) {
            XCTAssertEqual($0 as? CSVFile.Failure, .notText)
        }
    }
}
