import Foundation

/// Fills in a book's details from its ISBN using the Open Library API
/// (free, no account or key). The app's only network access.
enum BookLookup {
    enum LookupError: LocalizedError {
        case invalidISBN
        case notFound
        case network(String)

        var errorDescription: String? {
            switch self {
            case .invalidISBN: return "Not a valid ISBN"
            case .notFound: return "No match found"
            case .network(let detail): return "Couldn't reach Open Library (\(detail))"
            }
        }
    }

    /// Strips hyphens/spaces; returns the ISBN if it is 10 or 13 characters
    /// of the right shape (digits, with an X allowed last in an ISBN-10).
    static func normalizedISBN(_ raw: String) -> String? {
        let cleaned = raw.uppercased().filter { $0.isASCII && ($0.isNumber || $0 == "X") }
        switch cleaned.count {
        case 13 where !cleaned.contains("X"): return cleaned
        case 10 where !cleaned.dropLast().contains("X"): return cleaned
        default: return nil
        }
    }

    /// Open Library's own guidance is to identify the app with a contact address, which
    /// also earns a higher request limit.
    ///
    /// IF YOU FORK THIS APP, CHANGE THIS to your own address. Open Library sees this
    /// on every request and treats whoever it names as responsible for the traffic.
    static let contactAddress = "elmscanner@gjotsuki.net"
    static let userAgent = "ElmScanner/1.0 (\(contactAddress))"

    /// All lookups share this limit: at most 5 requests start in any 2 seconds.
    static let limiter = RateLimiter(maxRequests: 5, perSeconds: 2)

    /// The lookup the app uses: Open Library, with results kept on the device.
    static let shared = OpenLibraryBookLookupService(cacheURL: LookupCache.defaultURL)

    /// Reads Open Library's `jscmd=data` response.
    static func parse(_ data: Data, isbn: String) -> BookMetadata? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = root["ISBN:\(isbn)"] as? [String: Any],
              let title = (entry["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return nil }

        func names(_ key: String) -> [String] {
            (entry[key] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        }
        return BookMetadata(
            title: title,
            subtitle: (entry["subtitle"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            authors: names("authors").map { AuthorName(parsing: $0) },
            publisher: names("publishers").first,
            place: names("publish_places").first,
            publicationYear: (entry["publish_date"] as? String).flatMap(year(in:)),
            numberOfPages: (entry["number_of_pages"] as? Int).map(String.init),
            isbn: isbn,
            url: entry["url"] as? String,
            tags: Array(names("subjects").prefix(5))
        )
    }

    static func year(in text: String) -> Int? {
        text.range(of: #"\b(1[5-9]\d\d|20\d\d)\b"#, options: .regularExpression).flatMap { Int(text[$0]) }
    }
}

/// Allows at most `maxRequests` to start in any `perSeconds`, handing out start times
/// in the order requests arrive: a queue that keeps the app within Open Library's limits.
actor RateLimiter {
    private let maxRequests: Int
    private let window: TimeInterval
    /// The most recent start times handed out (some may be in the future).
    private var starts: [Date] = []

    init(maxRequests: Int, perSeconds: TimeInterval) {
        self.maxRequests = maxRequests
        self.window = perSeconds
    }

    /// The time a request that arrives at `now` may start.
    func reserve(now: Date = Date()) -> Date {
        var slot = now
        if starts.count >= maxRequests {
            slot = max(now, starts[starts.count - maxRequests].addingTimeInterval(window))
        }
        starts.append(slot)
        starts = Array(starts.suffix(maxRequests))
        return slot
    }

    /// Returns once this request may start.
    func waitForTurn() async throws {
        let wait = reserve().timeIntervalSinceNow
        if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
    }
}
