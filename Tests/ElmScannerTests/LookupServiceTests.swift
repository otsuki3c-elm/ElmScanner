import XCTest
@testable import ElmScanner

/// Answers every request from `handler`, so no test touches the real network.
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?
    nonisolated(unsafe) static var delay: TimeInterval = 0
    nonisolated(unsafe) static var requests: [URLRequest] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = nil; delay = 0; requests = []
    }
    static var requestCount: Int { lock.lock(); defer { lock.unlock() }; return requests.count }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let (status, body) = Self.handler?(request) ?? (500, "")
        let delay = Self.delay
        Self.lock.unlock()
        let respond = { [self] in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        if delay > 0 { DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: respond) } else { respond() }
    }
}

final class ContactBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?
    init(_ value: String?) { stored = value }
    var value: String? {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }
}

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSinceReferenceDate: 1_000_000)
    var date: Date { lock.lock(); defer { lock.unlock() }; return current }
    func advance(days: Double) { lock.lock(); current.addTimeInterval(days * 86400); lock.unlock() }
}

final class LookupServiceTests: XCTestCase {
    private let dune13 = "9780441172719"
    private let duneJSON = #"{"ISBN:9780441172719":{"title":"Dune","authors":[{"name":"Frank Herbert"}],"publish_date":"June 2006","publishers":[{"name":"Ace"}]}}"#
    private var clock = TestClock()
    /// The email address the service sees; nil means none has been entered.
    private var contact = ContactBox("reader@example.com")

    override func setUp() {
        StubProtocol.reset()
        clock = TestClock()
        contact = ContactBox("reader@example.com")
    }

    /// An answer from NDL with no records, as it sends for an ISBN it doesn't know.
    static let emptyRSS = #"<rss version="2.0"><channel><title>x</title></channel></rss>"#

    /// Serves Open Library and NDL separately; each answer is (status, body).
    private func stub(ol: (Int, String), ndl: (Int, String) = (200, LookupServiceTests.emptyRSS)) {
        StubProtocol.handler = { request in request.url?.host == "ndlsearch.ndl.go.jp" ? ndl : ol }
    }

    private func requestCount(host: String) -> Int {
        StubProtocol.requests.filter { $0.url?.host == host }.count
    }

    private func makeService(cacheURL: URL? = nil) -> OpenLibraryBookLookupService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let clock = clock
        let contact = contact
        return OpenLibraryBookLookupService(
            session: URLSession(configuration: config), cacheURL: cacheURL,
            limiter: RateLimiter(maxRequests: 1000, perSeconds: 1),
            ndlLimiter: RateLimiter(maxRequests: 1000, perSeconds: 1), retryDelay: 0, now: { clock.date },
            contact: { contact.value })
    }

    func testSecondLookupComesFromTheCache() async throws {
        stub(ol: (200, duneJSON))
        let service = makeService()
        let first = try await service.lookup(isbn: dune13)
        let second = try await service.lookup(isbn: dune13)
        XCTAssertEqual(first?.title, "Dune")
        XCTAssertEqual(first, second)
        XCTAssertEqual(StubProtocol.requestCount, 1)
        XCTAssertEqual(StubProtocol.requests[0].value(forHTTPHeaderField: "User-Agent"), "ElmScanner/1.0 (elmscanner@gjotsuki.net; reader@example.com)")
    }

    func testISBN10SharesTheISBN13Entry() async throws {
        stub(ol: (200, duneJSON))
        let service = makeService()
        _ = try await service.lookup(isbn: "0-441-17271-7")
        let again = try await service.lookup(isbn: dune13)
        XCTAssertEqual(again?.title, "Dune")
        XCTAssertEqual(StubProtocol.requestCount, 1)
        XCTAssertTrue(StubProtocol.requests[0].url!.absoluteString.contains("ISBN:\(dune13)"))
    }

    func testBadCheckDigitIsInvalid() async {
        let service = makeService()
        do {
            _ = try await service.lookup(isbn: "9780441172718")
            XCTFail("expected an error")
        } catch let error as BookLookup.LookupError {
            guard case .invalidISBN = error else { return XCTFail("wrong error \(error)") }
        } catch { XCTFail("wrong error \(error)") }
        XCTAssertEqual(StubProtocol.requestCount, 0)
    }

    func testNotFoundIsCachedThenRetriedAfterFourteenDays() async throws {
        stub(ol: (200, "{}"))
        let service = makeService()
        let first = try await service.lookup(isbn: dune13)
        XCTAssertNil(first)
        // Both catalogues were asked, once each.
        XCTAssertEqual(StubProtocol.requestCount, 2)
        clock.advance(days: 13)
        _ = try await service.lookup(isbn: dune13)
        XCTAssertEqual(StubProtocol.requestCount, 2)
        clock.advance(days: 2)
        _ = try await service.lookup(isbn: dune13)
        XCTAssertEqual(StubProtocol.requestCount, 4)
    }

    func testFoundEntriesLastSixMonths() async throws {
        stub(ol: (200, duneJSON))
        let service = makeService()
        _ = try await service.lookup(isbn: dune13)
        clock.advance(days: 179)
        _ = try await service.lookup(isbn: dune13)
        XCTAssertEqual(StubProtocol.requestCount, 1)
        clock.advance(days: 2)
        _ = try await service.lookup(isbn: dune13)
        XCTAssertEqual(StubProtocol.requestCount, 2)
    }

    func testStaleEntrySurvivesANetworkFailure() async throws {
        stub(ol: (200, duneJSON))
        let service = makeService()
        _ = try await service.lookup(isbn: dune13)
        clock.advance(days: 181)
        stub(ol: (500, ""), ndl: (500, ""))
        let stale = try await service.lookup(isbn: dune13)
        XCTAssertEqual(stale?.title, "Dune")
        XCTAssertEqual(StubProtocol.requestCount, 3)  // the first answer, then both catalogues failing
    }

    func testNetworkFailureWithNoCacheThrows() async {
        stub(ol: (429, ""), ndl: (429, ""))
        let service = makeService()
        do {
            _ = try await service.lookup(isbn: dune13)
            XCTFail("expected an error")
        } catch let error as BookLookup.LookupError {
            guard case .network = error else { return XCTFail("wrong error \(error)") }
        } catch { XCTFail("wrong error \(error)") }
        // Errors aren't cached: the next try asks again.
        stub(ol: (200, duneJSON))
        let retry = try? await service.lookup(isbn: dune13)
        XCTAssertEqual(retry?.title, "Dune")
    }

    func testNoEmailAddressMeansNoRequest() async throws {
        contact.value = nil
        stub(ol: (200, duneJSON))
        let service = makeService()
        do {
            _ = try await service.lookup(isbn: dune13)
            XCTFail("expected an error")
        } catch let error as BookLookup.LookupError {
            guard case .contactMissing = error else { return XCTFail("wrong error \(error)") }
        }
        XCTAssertEqual(StubProtocol.requestCount, 0)
        // Once an address is entered, the same lookup goes through.
        contact.value = "reader@example.com"
        let found = try await service.lookup(isbn: dune13)
        XCTAssertEqual(found?.title, "Dune")
    }

    func testEmailValidation() {
        for good in ["a@b.co", "first.last+tag@sub.example.org"] { XCTAssertTrue(ContactEmail.isValid(good), good) }
        for bad in ["", "no-at.example.com", "a@b", "a b@c.de", "a@b.c.", "x(y)@z.com", "a@b.com; evil"] {
            XCTAssertFalse(ContactEmail.isValid(bad), bad)
        }
    }

    // MARK: National Diet Library

    private let sosekiRSS = """
    <rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcndl="http://ndl.go.jp/dcndl/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:dcterms="http://purl.org/dc/terms/" version="2.0">
    <channel><title>x</title>
    <item>
      <title>別の本</title>
      <link>https://ndlsearch.ndl.go.jp/books/other</link>
      <dc:title>別の本</dc:title>
      <dc:identifier xsi:type="dcndl:ISBN">9784000000000</dc:identifier>
    </item>
    <item>
      <title>吾輩は猫である</title>
      <link>https://ndlsearch.ndl.go.jp/books/R100000002-I000002041889</link>
      <dc:title>吾輩は猫である</dc:title>
      <dc:creator>夏目, 漱石, 1867-1916</dc:creator>
      <dc:creator>講談社</dc:creator>
      <dcndl:seriesTitle>岩波文庫</dcndl:seriesTitle>
      <dc:publisher>岩波書店</dc:publisher>
      <dcndl:publicationPlace>JP</dcndl:publicationPlace>
      <dc:date xsi:type="dcterms:W3CDTF">1990</dc:date>
      <dc:extent>xii, 563p</dc:extent>
      <dc:identifier xsi:type="dcndl:ISBN">4-00-310101-4</dc:identifier>
      <dc:subject xsi:type="dcndl:NDC8">913.6</dc:subject>
      <dc:subject>日本文学</dc:subject>
    </item>
    </channel></rss>
    """
    private let soseki13 = "9784003101018"

    func testJapaneseISBNIsLookedUpAtNDLFirst() async throws {
        stub(ol: (200, duneJSON), ndl: (200, sosekiRSS))
        let book = try await makeService().lookup(isbn: soseki13)
        XCTAssertEqual(book?.title, "吾輩は猫である")
        XCTAssertEqual(book?.authors, [AuthorName(givenName: "漱石", familyName: "夏目"), AuthorName(familyName: "講談社")])
        XCTAssertEqual(book?.publisher, "岩波書店")
        XCTAssertEqual(book?.publicationYear, 1990)
        XCTAssertEqual(book?.numberOfPages, "563")
        XCTAssertEqual(book?.tags, ["日本文学"])
        XCTAssertNil(book?.place)
        XCTAssertEqual(book?.isbn, soseki13)
        XCTAssertEqual(book?.url, "https://ndlsearch.ndl.go.jp/books/R100000002-I000002041889")
        // Only NDL was asked, and without the user's address.
        XCTAssertEqual(StubProtocol.requestCount, 1)
        let request = StubProtocol.requests[0]
        XCTAssertEqual(request.url?.host, "ndlsearch.ndl.go.jp")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "ElmScanner/1.0 (elmscanner@gjotsuki.net)")
        XCTAssertTrue(request.url!.absoluteString.contains("isbn=\(soseki13)"))
    }

    func testJapaneseBookNDLDoesNotKnowFallsBackToOpenLibrary() async throws {
        stub(ol: (200, duneJSON.replacingOccurrences(of: "9780441172719", with: soseki13)))
        let book = try await makeService().lookup(isbn: soseki13)
        XCTAssertEqual(book?.title, "Dune")
        XCTAssertEqual(requestCount(host: "ndlsearch.ndl.go.jp"), 1)
        XCTAssertEqual(requestCount(host: "openlibrary.org"), 1)
    }

    func testOtherBookOpenLibraryDoesNotKnowFallsBackToNDL() async throws {
        stub(ol: (200, "{}"), ndl: (200, sosekiRSS))
        let book = try await makeService().lookup(isbn: soseki13.replacingOccurrences(of: "9784003101018", with: "9784003101018"))
        XCTAssertEqual(book?.title, "吾輩は猫である")
        // A non-Japanese ISBN goes the other way round: Open Library, then NDL.
        stub(ol: (200, "{}"), ndl: (200, #"<rss><channel><item><dc:title xmlns:dc="x">T</dc:title><dc:identifier xmlns:dc="x" xmlns:xsi="y" xsi:type="dcndl:ISBN">9780441172719</dc:identifier></item></channel></rss>"#))
        StubProtocol.requests = []
        let other = try await makeService().lookup(isbn: dune13)
        XCTAssertEqual(other?.title, "T")
        XCTAssertEqual(StubProtocol.requests.map { $0.url?.host }, ["openlibrary.org", "ndlsearch.ndl.go.jp"])
    }

    func testNDLTooManyRequestsIsWaitedOut() async throws {
        let attempts = ContactBox(nil)  // counts attempts: "1", "2", …
        let rss = sosekiRSS
        StubProtocol.handler = { _ in
            let n = (Int(attempts.value ?? "0") ?? 0) + 1
            attempts.value = String(n)
            return n < 3 ? (429, "") : (200, rss)
        }
        let book = try await makeService().lookup(isbn: soseki13)
        XCTAssertEqual(book?.title, "吾輩は猫である")
        XCTAssertEqual(StubProtocol.requestCount, 3)
    }

    func testNotFoundIsNotCachedWhenOneCatalogueCouldNotBeReached() async throws {
        stub(ol: (500, ""), ndl: (200, Self.emptyRSS))
        let service = makeService()
        do {
            _ = try await service.lookup(isbn: dune13)
            XCTFail("expected an error")
        } catch let error as BookLookup.LookupError {
            guard case .network = error else { return XCTFail("wrong error \(error)") }
        }
        // Open Library is back and knows the book: nothing wrong was remembered.
        stub(ol: (200, duneJSON))
        let book = try await service.lookup(isbn: dune13)
        XCTAssertEqual(book?.title, "Dune")
    }

    func testCreatorDatesAndPagesAreCleanedUp() {
        XCTAssertEqual(NDL.author(from: "夏目, 漱石, 1867-1916"), AuthorName(givenName: "漱石", familyName: "夏目"))
        XCTAssertEqual(NDL.author(from: "木村, 衣有子, 1975-"), AuthorName(givenName: "衣有子", familyName: "木村"))
        XCTAssertEqual(NDL.author(from: "Herbert, Frank"), AuthorName(givenName: "Frank", familyName: "Herbert"))
        XCTAssertEqual(NDL.pages(in: "563p"), "563")
        XCTAssertEqual(NDL.pages(in: "xii, 300p ; 21cm"), "300")
        XCTAssertNil(NDL.pages(in: "1 v."))
    }

    func testPublishDateParsing() {
        XCTAssertEqual(BookLookup.year(in: "June 2006"), 2006)
        XCTAssertEqual(BookLookup.year(in: "1999"), 1999)
        XCTAssertNil(BookLookup.year(in: "n.d."))
    }

    func testConcurrentLookupsMakeOneRequest() async throws {
        stub(ol: (200, duneJSON))
        StubProtocol.delay = 0.3
        let service = makeService()
        async let a = service.lookup(isbn: dune13)
        async let b = service.lookup(isbn: "0441172717")
        let (first, second) = try await (a, b)
        XCTAssertEqual(first?.title, "Dune")
        XCTAssertEqual(first, second)
        XCTAssertEqual(StubProtocol.requestCount, 1)
    }

    func testCacheSurvivesARestart() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "lookup-cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        stub(ol: (200, duneJSON))
        _ = try await makeService(cacheURL: url).lookup(isbn: dune13)
        stub(ol: (500, ""), ndl: (500, ""))
        let reopened = try await makeService(cacheURL: url).lookup(isbn: dune13)
        XCTAssertEqual(reopened?.title, "Dune")
        XCTAssertEqual(StubProtocol.requestCount, 1)
    }
}
