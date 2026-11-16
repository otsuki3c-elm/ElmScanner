import CryptoKit
import Foundation
import Observation

/// ISBN-10 / ISBN-13 handling: one book is one ISBN-13, however it was typed.
enum ISBN {
    /// The ISBN-13 for an ISBN-10 or ISBN-13 with a correct check digit, else nil.
    static func canonical13(_ raw: String) -> String? {
        guard let cleaned = BookLookup.normalizedISBN(raw) else { return nil }
        if cleaned.count == 13 { return ISBNBarcode.hasValidCheckDigit(cleaned) ? cleaned : nil }
        // ISBN-10: digits weighted 10…1 (X counts as 10 in the last place) sum to a multiple of 11.
        let values = cleaned.map { $0 == "X" ? 10 : $0.wholeNumberValue! }
        guard values.enumerated().reduce(0, { $0 + $1.element * (10 - $1.offset) }) % 11 == 0 else { return nil }
        let body = "978" + cleaned.dropLast()
        let sum = body.compactMap(\.wholeNumberValue).enumerated().reduce(0) { $0 + $1.element * ($1.offset % 2 == 0 ? 1 : 3) }
        return body + String((10 - sum % 10) % 10)
    }

    /// The ISBN-10 of an ISBN-13 that starts 978 (979 books have none), else nil.
    static func isbn10(fromISBN13 isbn13: String) -> String? {
        guard isbn13.count == 13, isbn13.hasPrefix("978") else { return nil }
        let body = isbn13.dropFirst(3).dropLast()
        let sum = body.compactMap(\.wholeNumberValue).enumerated().reduce(0) { $0 + $1.element * (10 - $1.offset) }
        let check = (11 - sum % 11) % 11
        return body + (check == 10 ? "X" : String(check))
    }
}

/// A rank earned at a number of scanned books. The list lives in `Ranks.json`.
struct Rank: Codable, Identifiable, Equatable {
    var books: Int
    var title: String
    var message: String
    var id: Int { books }

    private struct File: Decodable { var ranks: [Rank] }

    static func load(from url: URL) -> [Rank] {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.ranks.sorted { $0.books < $1.books }
    }

    /// The ranks bundled with the app (`Ranks.json`).
    static var bundled: [Rank] {
        let ranks = Bundle.main.url(forResource: "Ranks", withExtension: "json").map(load(from:)) ?? []
        // The file holds the English; the title and message are looked up in the string catalog.
        return ranks.map { Rank(books: $0.books, title: localized($0.title), message: localized($0.message)) }
    }

    private static func localized(_ text: String) -> String {
        Bundle.main.localizedString(forKey: text, value: text, table: nil)
    }
}

/// A rank that was just reached, waiting to be shown.
struct Award: Identifiable, Equatable {
    var rank: Rank
    var count: Int
    var id: Int { rank.books }
}

/// Counts the different books the user has ever scanned, without keeping a record
/// of which ones: only a one-way hash of each ISBN-13 is stored, in a hidden log.
/// A book that's scanned again, or removed from the list and scanned again, hashes
/// to the same value and isn't counted twice. The count never goes down.
@Observable
@MainActor
final class AchievementTracker {
    private(set) var count = 0
    /// The newest rank reached, until the user dismisses it.
    var pending: Award?

    @ObservationIgnored private var hashes = Set<String>()
    @ObservationIgnored private let logURL: URL?
    @ObservationIgnored private let ranks: [Rank]

    /// The hidden log (a dot-file, so Finder doesn't list it).
    static var defaultLogURL: URL {
        URL.applicationSupportDirectory.appending(path: "ElmScanner/.scan-log")
    }

    /// The tracker the apps use: the real log and the bundled ranks.
    static func standard() -> AchievementTracker {
        AchievementTracker(logURL: defaultLogURL, ranks: Rank.bundled)
    }

    init(logURL: URL?, ranks: [Rank]) {
        self.logURL = logURL
        self.ranks = ranks
        if let logURL, let data = try? Data(contentsOf: logURL),
           let stored = try? JSONDecoder().decode([String].self, from: data) {
            hashes = Set(stored)
        }
        count = hashes.count
    }

    /// A salted SHA-256 of the ISBN-13, as hex.
    nonisolated static func hash(_ isbn13: String) -> String {
        SHA256.hash(data: Data("ElmScanner-book:\(isbn13)".utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Counts an ISBN if it's valid and new, and queues the rank it reaches, if any.
    func record(_ raw: String) { record(all: [raw]) }

    func record(all isbns: [String]) {
        let before = count
        for raw in isbns {
            guard let isbn = ISBN.canonical13(raw) else { continue }
            hashes.insert(Self.hash(isbn))
        }
        guard hashes.count != before else { return }
        count = hashes.count
        save()
        // Several ranks passed at once (a restored list): show the highest.
        if let rank = ranks.last(where: { $0.books > before && $0.books <= count }) {
            pending = Award(rank: rank, count: count)
        }
    }

    #if DEBUG
    /// For screenshots only (see DemoMode): pretend this many books were scanned, optionally with its rank popup showing.
    func setDemo(count demoCount: Int, showAward: Bool) {
        count = demoCount
        if showAward, let rank = ranks.last(where: { $0.books <= demoCount }) { pending = Award(rank: rank, count: demoCount) }
    }
    #endif

    /// The highest rank reached so far, or nil before the first.
    var currentRank: Rank? { ranks.last { $0.books <= count } }

    func dismiss() { pending = nil }

    private func save() {
        guard let logURL else { return }
        do {
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(hashes.sorted()).write(to: logURL, options: .atomic)
        } catch {
            // The count is a nicety; the app keeps working without the log.
        }
    }
}
