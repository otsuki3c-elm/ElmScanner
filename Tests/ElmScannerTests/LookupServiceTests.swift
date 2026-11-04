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

    override func setUp() {
        StubProtocol.reset()
        clock = TestClock()
    }

    private func makeService(cacheURL: URL? = nil) -> OpenLibraryBookLookupService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let clock = clock
        return OpenLibraryBookLookupService(
            session: URLSession(configuration: config), cacheURL: cacheURL,
            limiter: RateLimiter(maxRequests: 1000, perSeconds: 1), now: { clock.date })
    }

    func testSecondLookupComesFromTheCache() async throws {
        StubProtocol.handler = { [duneJSON] _ in (200, duneJSON) }
        let service = makeService()
        let first = try await service.lookup(isbn: dune13)
        let second = try await service.lookup(isbn: dune13)
        XCTAssertEqual(first?.title, "Dune")
        XCTAssertEqual(first, second)
        XCTAssertEqual(StubProtocol.requestCount, 1)
        XCTAssertEqual(StubProtocol.requests[0].value(forHTTPHeaderField: "User-Agent"), "ElmScanner/1.0 (elmscanner@gjotsuki.net)")
    }

    func testISBN10SharesTheISBN13Entry() async throws {
        StubProtocol.handler = { [duneJSON] _ in (200, duneJSON) }
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
        StubProtocol.handler = { _ in (200, "{}") }
        let service = makeService()
        let first = try await service.lookup(isbn: dune13)
        XCTAssertNil(first)
        clock.advance(days: 13)
        _ = try await service.lookup(isbn: dune13)
        XCTAssertEqual(StubProtocol.requestCount, 1)
        clock.advance(days: 2)
        _ = try await service.lookup(isbn: dune13)
        XCTAssertEqual(StubProtocol.requestCount, 2)
    }

    func testFoundEntriesLastSixMonths() async throws {
        StubProtocol.handler = { [duneJSON] _ in (200, duneJSON) }
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
        StubProtocol.handler = { [duneJSON] _ in (200, duneJSON) }
        let service = makeService()
        _ = try await service.lookup(isbn: dune13)
        clock.advance(days: 181)
        StubProtocol.handler = { _ in (500, "") }
        let stale = try await service.lookup(isbn: dune13)
        XCTAssertEqual(stale?.title, "Dune")
        XCTAssertEqual(StubProtocol.requestCount, 2)
    }

    func testNetworkFailureWithNoCacheThrows() async {
        StubProtocol.handler = { _ in (429, "") }
        let service = makeService()
        do {
            _ = try await service.lookup(isbn: dune13)
            XCTFail("expected an error")
        } catch let error as BookLookup.LookupError {
            guard case .network = error else { return XCTFail("wrong error \(error)") }
        } catch { XCTFail("wrong error \(error)") }
        // Errors aren't cached: the next try asks again.
        StubProtocol.handler = { [duneJSON] _ in (200, duneJSON) }
        let retry = try? await service.lookup(isbn: dune13)
        XCTAssertEqual(retry?.title, "Dune")
    }

    func testPublishDateParsing() {
        XCTAssertEqual(BookLookup.year(in: "June 2006"), 2006)
        XCTAssertEqual(BookLookup.year(in: "1999"), 1999)
        XCTAssertNil(BookLookup.year(in: "n.d."))
    }

    func testConcurrentLookupsMakeOneRequest() async throws {
        StubProtocol.handler = { [duneJSON] _ in (200, duneJSON) }
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
        StubProtocol.handler = { [duneJSON] _ in (200, duneJSON) }
        _ = try await makeService(cacheURL: url).lookup(isbn: dune13)
        StubProtocol.handler = { _ in (500, "") }
        let reopened = try await makeService(cacheURL: url).lookup(isbn: dune13)
        XCTAssertEqual(reopened?.title, "Dune")
        XCTAssertEqual(StubProtocol.requestCount, 1)
    }
}
