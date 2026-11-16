import Foundation

/// Finds a book's details from its ISBN. Callers use only this, so the data
/// source can change without touching them.
protocol BookLookupService: Sendable {
    /// The book's details, or nil if the source has no such book.
    /// Throws `BookLookup.LookupError` for a bad ISBN or an unreachable source.
    func lookup(isbn: String) async throws -> BookMetadata?
}

/// One remembered answer, kept by ISBN-13. A book that wasn't found is remembered too.
struct LookupCacheEntry: Codable, Equatable {
    var isbn13: String
    /// nil when the book wasn't found.
    var metadata: BookMetadata?
    var fetchedAt: Date
    /// Which catalogue answered ("openlibrary" or "ndl"); nil for a not-found or an older entry.
    var source: String?
}

/// Answers kept on the device so scanning the same book again needs no network.
/// Saved as one small JSON file; with no file URL it lives only in memory.
struct LookupCache {
    /// Next to the unexported-books file, inside the app's private storage.
    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "ElmScanner/lookup-cache.json")
    }

    private(set) var entries: [String: LookupCacheEntry] = [:]
    private let url: URL?

    init(url: URL? = nil) {
        self.url = url
        guard let url, let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode([LookupCacheEntry].self, from: data) else { return }
        entries = Dictionary(saved.map { ($0.isbn13, $0) }, uniquingKeysWith: { _, new in new })
    }

    subscript(isbn13: String) -> LookupCacheEntry? { entries[isbn13] }

    mutating func store(_ entry: LookupCacheEntry) {
        entries[entry.isbn13] = entry
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(Array(entries.values)).write(to: url, options: .atomic)
        } catch {
            // The cache is an optimization; the app works without it.
        }
    }
}

/// Looks books up on Open Library, remembering every answer on the device.
actor OpenLibraryBookLookupService: BookLookupService {
    /// How long a found book is trusted before it is fetched again.
    static let foundLifetime: TimeInterval = 180 * 24 * 3600
    /// How long a "not found" is trusted; short, since Open Library keeps adding books.
    static let notFoundLifetime: TimeInterval = 14 * 24 * 3600

    private let session: URLSession
    private let limiter: RateLimiter
    private let ndlLimiter: RateLimiter
    private let dnbLimiter: RateLimiter
    private let bnfLimiter: RateLimiter
    private let bneLimiter: RateLimiter
    /// How long to wait before asking NDL again after "too many requests"; each retry waits longer.
    private let retryDelay: TimeInterval
    private let now: @Sendable () -> Date
    private let contact: @Sendable () -> String?
    private var cache: LookupCache
    private var inFlight: [String: Task<BookMetadata?, Error>] = [:]

    /// - Parameter cacheURL: where answers are kept; nil keeps them in memory only.
    init(session: URLSession = .shared,
         cacheURL: URL? = nil,
         limiter: RateLimiter = BookLookup.limiter,
         ndlLimiter: RateLimiter = BookLookup.ndlLimiter,
         dnbLimiter: RateLimiter = BookLookup.dnbLimiter,
         bnfLimiter: RateLimiter = BookLookup.bnfLimiter,
         bneLimiter: RateLimiter = BookLookup.bneLimiter,
         retryDelay: TimeInterval = 3,
         now: @escaping @Sendable () -> Date = { Date() },
         contact: @escaping @Sendable () -> String? = { ContactEmail.stored() }) {
        self.contact = contact
        self.session = session
        self.limiter = limiter
        self.ndlLimiter = ndlLimiter
        self.dnbLimiter = dnbLimiter
        self.bnfLimiter = bnfLimiter
        self.bneLimiter = bneLimiter
        self.retryDelay = retryDelay
        self.now = now
        self.cache = LookupCache(url: cacheURL)
    }

    func lookup(isbn: String) async throws -> BookMetadata? {
        guard let isbn13 = ISBN.canonical13(isbn) else { throw BookLookup.LookupError.invalidISBN }
        let cached = cache[isbn13]
        if let cached, isFresh(cached) { return cached.metadata }
        // Several callers asking for the same book share one request.
        if let running = inFlight[isbn13] { return try await running.value }
        let task = Task { try await fetchAndStore(isbn13, stale: cached) }
        inFlight[isbn13] = task
        defer { inFlight[isbn13] = nil }
        return try await task.value
    }

    private func isFresh(_ entry: LookupCacheEntry) -> Bool {
        let lifetime = entry.metadata == nil ? Self.notFoundLifetime : Self.foundLifetime
        return now().timeIntervalSince(entry.fetchedAt) < lifetime
    }

    private func fetchAndStore(_ isbn13: String, stale: LookupCacheEntry?) async throws -> BookMetadata? {
        do {
            let (metadata, source) = try await fetch(isbn13)
            cache.store(LookupCacheEntry(isbn13: isbn13, metadata: metadata, fetchedAt: now(), source: source))
            return metadata
        } catch let error as BookLookup.LookupError {
            // An old answer beats none. Errors themselves are never cached. A stale
            // "not found" doesn't count: showing it would hide that the network failed.
            if let stale, let metadata = stale.metadata { return metadata }
            throw error
        }
    }

    private enum Source: String { case openLibrary = "openlibrary", ndl, dnb, bnf, bne }

    /// Asks the catalogues in turn: the national library first for a Japanese (NDL), German (DNB),
    /// French (BnF) or Spanish (BNE) ISBN, Open Library first for any other. The first to know the book wins. If none knows it, that is cached as "not found"
    /// only when every one of them answered; if one couldn't be reached, nothing is cached.
    private func fetch(_ isbn13: String) async throws -> (BookMetadata?, String?) {
        // Open Library wants every request to name a contact; with none, send nothing.
        guard let contact = contact() else { throw BookLookup.LookupError.contactMissing }
        let order: [Source]
        if NDL.isJapanese(isbn13: isbn13) { order = [.ndl, .openLibrary] }
        else if DNB.isGerman(isbn13: isbn13) { order = [.dnb, .openLibrary, .ndl] }
        else if BnF.isFrench(isbn13: isbn13) { order = [.bnf, .openLibrary, .ndl] }
        else if BNE.isSpanish(isbn13: isbn13) { order = [.bne, .openLibrary, .ndl] }
        else { order = [.openLibrary, .ndl] }
        var failure: BookLookup.LookupError?
        for source in order {
            do {
                let found: BookMetadata?
                switch source {
                case .openLibrary: found = try await fetchOpenLibrary(isbn13, contact: contact)
                case .ndl: found = try await fetchNDL(isbn13)
                case .dnb: found = try await fetchNationalLibrary(DNB.url(isbn13: isbn13), limiter: dnbLimiter) { DNB.parse($0, isbn13: isbn13) }
                case .bnf:
                    // The BnF's open licence asks for its name and the date the record was taken.
                    found = try await fetchNationalLibrary(BnF.url(isbn13: isbn13), limiter: bnfLimiter) { BnF.parse($0, isbn13: isbn13) }
                        .map { var book = $0; book.note = BnF.attribution(on: now()); return book }
                case .bne: found = try await fetchNationalLibrary(BNE.url(isbn13: isbn13), limiter: bneLimiter) { BNE.parse($0, isbn13: isbn13) }
                }
                if let found { return (found, source.rawValue) }
            } catch let error as BookLookup.LookupError {
                failure = error
            }
        }
        if let failure { throw failure }
        return (nil, nil)
    }

    private func fetchOpenLibrary(_ isbn13: String, contact: String) async throws -> BookMetadata? {
        var components = URLComponents(string: "https://openlibrary.org/api/books")!
        components.queryItems = [
            URLQueryItem(name: "bibkeys", value: "ISBN:\(isbn13)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "jscmd", value: "data")
        ]
        var request = URLRequest(url: components.url!, timeoutInterval: 10)
        request.setValue(BookLookup.userAgent(contact: contact), forHTTPHeaderField: "User-Agent")
        try await limiter.waitForTurn()
        // Includes 429 and 5xx.
        return BookLookup.parse(try await send(request), isbn: isbn13)
    }

    private func fetchNDL(_ isbn13: String) async throws -> BookMetadata? {
        var request = URLRequest(url: NDL.url(isbn13: isbn13), timeoutInterval: 10)
        request.setValue(BookLookup.plainUserAgent, forHTTPHeaderField: "User-Agent")
        var attempt = 0
        while true {
            try await ndlLimiter.waitForTurn()
            do {
                return NDL.parse(try await send(request), isbn13: isbn13)
            } catch BookLookup.LookupError.network(let detail) where detail == "HTTP 429" && attempt < 2 {
                // NDL limits simultaneous requests and answers "too many": wait, then ask again.
                attempt += 1
                try await Task.sleep(for: .seconds(retryDelay * Double(attempt)))
            }
        }
    }

    /// One request to a national library that needs no contact address: the app's own User-Agent only.
    private func fetchNationalLibrary(_ url: URL, limiter: RateLimiter,
                                      parse: (Data) -> BookMetadata?) async throws -> BookMetadata? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(BookLookup.plainUserAgent, forHTTPHeaderField: "User-Agent")
        try await limiter.waitForTurn()
        return parse(try await send(request))
    }

    private func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw BookLookup.LookupError.network("HTTP \(http.statusCode)")
            }
            return data
        } catch let error as BookLookup.LookupError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw BookLookup.LookupError.network(error.localizedDescription)
        }
    }
}
