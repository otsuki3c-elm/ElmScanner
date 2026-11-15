import CloudKit
import XCTest
@testable import ElmScanner

@MainActor
final class LibrarySenderTests: XCTestCase {
    private final class Spy: LibrarySending {
        var sent: [BookMetadata] = []
        func send(_ metadata: BookMetadata) { sent.append(metadata) }
    }

    private struct Fixed: BookLookupService {
        let metadata: BookMetadata?
        func lookup(isbn: String) async throws -> BookMetadata? { metadata }
    }

    private let dune = BookMetadata(
        title: "Dune", subtitle: "A Novel", authors: [AuthorName(parsing: "Frank Herbert")],
        publisher: "Ace", place: nil, publicationYear: 1990, numberOfPages: "592",
        isbn: "9780441172719", url: nil, tags: ["sf"])

    func testRecordCarriesTheBookAndIsNamedByISBN13() {
        let zone = CKRecordZone.ID(zoneName: LibrarySender.zoneName, ownerName: CKCurrentUserDefaultName)
        let record = LibrarySender.record(for: dune, zoneID: zone)
        XCTAssertEqual(record.recordType, "ScannedBook")
        XCTAssertEqual(record.recordID.recordName, "isbn-9780441172719")
        XCTAssertEqual(record["title"] as? String, "Dune")
        XCTAssertEqual(record["publicationYear"] as? Int64, 1990)
        XCTAssertEqual(record["tags"] as? [String], ["sf"])
        XCTAssertTrue((record["authors"] as? String)?.contains("Herbert") == true)
    }

    func testISBN10AndISBN13GiveTheSameRecordName() {
        var old = dune
        old.isbn = "0441172717"
        XCTAssertEqual(LibrarySender.recordName(for: old), LibrarySender.recordName(for: dune))
    }

    func testFoundBookIsHandedToTheLibrary() async {
        let spy = Spy()
        let session = ScanSession(lookup: Fixed(metadata: dune), library: spy)
        session.add("9780441172719")
        for _ in 0..<50 where spy.sent.isEmpty { try? await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(spy.sent.map(\.title), ["Dune"])
    }

    func testNotFoundBookIsNotSent() async {
        let spy = Spy()
        let session = ScanSession(lookup: Fixed(metadata: nil), library: spy)
        session.add("9780441172719")
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(spy.sent.isEmpty)
    }

    func testEditedBookIsSentAgain() {
        let spy = Spy()
        let session = ScanSession(library: spy)
        session.add("9780441172719")
        var edited = dune
        edited.title = "Dune (edited)"
        session.update(session.books[0].id, with: edited)
        XCTAssertEqual(spy.sent.last?.title, "Dune (edited)")
    }
}
