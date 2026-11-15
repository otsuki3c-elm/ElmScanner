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

    func testEditFormKeepsOrganizationAuthors() {
        let authors = [AuthorName(familyName: "Statistical Office of the European Communities"),
                       AuthorName(givenName: "Frank", familyName: "Herbert")]
        XCTAssertEqual(BookEditForm.parseAuthors(BookEditForm.editableAuthors(authors)), authors)
    }

    func testFileNamesHaveNoSlash() {
        for format in ExportService.Format.allCases { XCTAssertFalse(format.fileName.contains("/"), format.title) }
    }

    func testControlCharactersDontBreakXML() throws {
        var odd = dune
        odd.title = "Du\u{0B}ne\u{0}"
        let data = try ExportService.data(for: [odd], format: .mods)
        XCTAssertTrue(XMLParser(data: data).parse())
    }

    func testOrganizationAuthorKeepsItsBraces() {
        var org = dune
        org.authors = [AuthorName(familyName: "Statistical Office"), AuthorName(givenName: "Frank", familyName: "Herbert")]
        for text in [ExportService.bibtex([org]), ExportService.biblatex([org])] {
            XCTAssertTrue(text.contains("author = {{Statistical Office} and Herbert, Frank}"), text)
        }
    }

    // MARK: Achievements

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "ElmScannerTests-\(UUID().uuidString)")
    }

    func testISBN10AndISBN13AreTheSameBook() {
        XCTAssertEqual(ISBN.canonical13("0441172717"), "9780441172719")
        XCTAssertEqual(ISBN.canonical13("978-0-441-17271-9"), "9780441172719")
        XCTAssertNil(ISBN.canonical13("0441172718"))
        XCTAssertNil(ISBN.canonical13("9780441172718"))
    }

    @MainActor
    func testEachBookIsCountedOnceAndOnlyAHashIsKept() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let ranks = [Rank(books: 1, title: "One", message: "m"), Rank(books: 2, title: "Two", message: "m")]
        let tracker = AchievementTracker(logURL: url, ranks: ranks)

        tracker.record("9780441172719")
        XCTAssertEqual(tracker.count, 1)
        XCTAssertEqual(tracker.pending?.rank.title, "One")
        tracker.dismiss()

        tracker.record("0441172717")        // the same book as ISBN-10
        tracker.record("9780441172719")     // scanned again
        tracker.record("9780441172718")     // bad check digit
        XCTAssertEqual(tracker.count, 1)
        XCTAssertNil(tracker.pending)

        tracker.record("9780857073006")
        XCTAssertEqual(tracker.count, 2)
        XCTAssertEqual(tracker.pending?.rank.title, "Two")

        let log = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(log.contains("9780441172719"))
        XCTAssertFalse(log.contains("9780857073006"))
        XCTAssertEqual(AchievementTracker(logURL: url, ranks: ranks).count, 2)
    }

    @MainActor
    func testRemovingABookDoesNotLowerOrRepeatTheCount() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = AchievementTracker(logURL: url, ranks: [])
        let session = ScanSession(achievements: tracker)
        session.add("9780441172719")
        XCTAssertEqual(tracker.count, 1)
        session.removeAll()
        XCTAssertEqual(tracker.count, 1)
        session.add("9780441172719")
        XCTAssertEqual(tracker.count, 1)
        XCTAssertEqual(session.add("0441172717"), .duplicate(session.books[0].id))
    }

    @MainActor
    func testSeveralRanksAtOnceShowTheHighest() {
        let ranks = [1, 2, 3].map { Rank(books: $0, title: "R\($0)", message: "m") }
        let tracker = AchievementTracker(logURL: nil, ranks: ranks)
        tracker.record(all: ["9780441172719", "9780857073006", "9780061120084"])
        XCTAssertEqual(tracker.pending?.rank.title, "R3")
    }

    @MainActor
    func testCurrentRankIsNilUntilTheFirstRankThenTheHighestReached() {
        let ranks = [1, 3].map { Rank(books: $0, title: "R\($0)", message: "m") }
        let tracker = AchievementTracker(logURL: nil, ranks: ranks)
        XCTAssertNil(tracker.currentRank)
        tracker.record("9780441172719")
        XCTAssertEqual(tracker.currentRank?.title, "R1")
        tracker.record("9780857073006")
        XCTAssertEqual(tracker.currentRank?.title, "R1")
        tracker.record("9780061120084")
        XCTAssertEqual(tracker.currentRank?.title, "R3")
    }

    func testBundledRanksFileHasTheRequestedThresholds() {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Resources/Shared/Ranks.json")
        let ranks = Rank.load(from: file)
        XCTAssertEqual(ranks.map(\.books), [1, 5, 10, 30, 80, 116, 218, 300, 500, 1000])
        XCTAssertTrue(ranks.allSatisfy { !$0.title.isEmpty && !$0.message.isEmpty })
    }

    func testLookupQueueAllowsFiveRequestsPerTwoSeconds() async {
        let limiter = RateLimiter(maxRequests: 5, perSeconds: 2)
        let t0 = Date(timeIntervalSinceReferenceDate: 1000)
        var slots: [Date] = []
        for _ in 0..<12 { slots.append(await limiter.reserve(now: t0)) }
        // The first 5 go at once, the next 5 two seconds later, the next 2 two seconds after that.
        XCTAssertEqual(slots.map { $0.timeIntervalSince(t0) }, [0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 4, 4])
        // Never more than 5 starts in any 2-second window.
        for slot in slots {
            let inWindow = slots.filter { $0 >= slot && $0 < slot.addingTimeInterval(2) }.count
            XCTAssertLessThanOrEqual(inWindow, 5)
        }
        // A request arriving much later isn't held up.
        let late = await limiter.reserve(now: t0.addingTimeInterval(60))
        XCTAssertEqual(late, t0.addingTimeInterval(60))
    }

    func testLookupIdentifiesTheApp() {
        let agent = BookLookup.userAgent(contact: "reader@example.com")
        XCTAssertTrue(agent.contains("elmscanner@gjotsuki.net"))
        XCTAssertTrue(agent.contains("reader@example.com"))
    }

    func testTipProductIsNamedAfterTheBundleID() {
        XCTAssertEqual(TipJar.productID(bundleID: "com.otsuki.elmscanner.ElmScanner"), "com.otsuki.elmscanner.ElmScanner.tip")
        XCTAssertEqual(TipJar.productID(bundleID: nil), "ElmScanner.tip")
    }

    @MainActor
    func testTipJarStartsLoadingAndNothingDependsOnIt() {
        // A fresh tip jar has bought nothing and gates nothing: it only reports its own state.
        let jar = TipJar(productID: "test.tip")
        XCTAssertEqual(jar.state, .loading)
        XCTAssertNil(jar.product)
    }

    func testRegistrationGroups() {
        XCTAssertEqual(ISBNRegion.group(ofISBN13: "9780441172719"), "0")
        XCTAssertEqual(ISBNRegion.group(ofISBN13: "9784003101018"), "4")
        XCTAssertEqual(ISBNRegion.group(ofISBN13: "9783161484100"), "3")      // German
        XCTAssertEqual(ISBNRegion.group(ofISBN13: "9788804668282"), "88")     // Italian
        XCTAssertEqual(ISBNRegion.group(ofISBN13: "9789577290427"), "957")    // Taiwan
        XCTAssertEqual(ISBNRegion.group(ofISBN13: "9791190000000"), "11")     // Korea (979-11)
        XCTAssertEqual(ISBNRegion.group(ofISBN13: "9798000000007"), "8")      // USA (979-8)
        XCTAssertNil(ISBNRegion.group(ofISBN13: "123"))
    }

    func testOnlyOtherLanguageAreasGetANotice() {
        XCTAssertNil(ISBNRegion.notice(forISBN: "9780441172719"))   // English
        XCTAssertNil(ISBNRegion.notice(forISBN: "9784003101018"))   // Japanese
        XCTAssertNil(ISBNRegion.notice(forISBN: "9798000000007"))   // USA (979-8)
        XCTAssertNil(ISBNRegion.notice(forISBN: "12345"))           // not an ISBN
        let german = ISBNRegion.notice(forISBN: "9783161484100")
        XCTAssertTrue(german?.contains("German-language area") == true, german ?? "nil")
        // An ISBN-10 is placed by its ISBN-13 form.
        XCTAssertTrue(ISBNRegion.notice(forISBN: "3-16-148410-X")?.contains("German") == true)
        // A group the table doesn't name still gets a notice, worded generally.
        let unnamed = ISBNRegion.notice(forISBN: "9786000000004")
        XCTAssertTrue(unnamed?.contains("outside the English- and Japanese-language areas") == true, unnamed ?? "nil")
    }

    @MainActor
    func testNotFoundBookFromAnotherLanguageAreaShowsTheNotice() async throws {
        struct NotFound: BookLookupService {
            func lookup(isbn: String) async throws -> BookMetadata? { nil }
        }
        let session = ScanSession(lookup: NotFound())
        session.add("9783161484100")
        session.add("9780441172719")
        try await Task.sleep(for: .milliseconds(300))
        func reason(_ isbn: String) -> String? {
            if case .failed(let text) = session.books.first(where: { $0.isbn == isbn })?.state { return text }
            return nil
        }
        XCTAssertTrue(reason("9783161484100")?.contains("German-language area") == true)
        XCTAssertEqual(reason("9780441172719"), "No match found")
    }
}
