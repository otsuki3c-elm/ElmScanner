import Foundation
import Observation

/// The list of scanned books: each new ISBN is added once and looked up.
///
/// Given a `storeURL`, the books not yet exported are saved there after every
/// change and reloaded at the next launch, so a crash or force-quit loses nothing.
@Observable
@MainActor
final class ScanSession {
    var books: [ScannedBook] = [] { didSet { save() } }
    /// The ISBN most recently added, for a brief highlight in the UI.
    var lastAdded: String?

    var foundBooks: [BookMetadata] { books.compactMap(\.metadata) }

    @ObservationIgnored private let storeURL: URL?
    @ObservationIgnored private let lookupService: any BookLookupService
    /// Gets each book once it is found (and again when edited); nil where books aren't sent on.
    @ObservationIgnored private let library: (any LibrarySending)?
    /// Counts the different books ever scanned; nil where achievements aren't wanted.
    let achievements: AchievementTracker?
    /// Books already exported: still listed, but no longer worth restoring.
    @ObservationIgnored private var exported = Set<UUID>()

    /// Where the iPhone app keeps its unexported books.
    static var defaultStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "ElmScanner/scanned-books.json")
    }

    init(storeURL: URL? = nil, achievements: AchievementTracker? = nil,
         lookup: any BookLookupService = BookLookup.shared,
         library: (any LibrarySending)? = nil) {
        self.storeURL = storeURL
        self.library = library
        self.lookupService = lookup
        self.achievements = achievements
        guard let storeURL else { return }
        // Assigned here, so the didSet doesn't rewrite the file mid-load.
        books = ScanStore.load(from: storeURL)
        for book in books where book.metadata == nil { lookUp(book.isbn) }
        // Books restored from before achievements existed still count.
        achievements?.record(all: books.map(\.isbn))
    }

    /// What `add` did with an ISBN.
    enum AddResult: Equatable {
        case added
        /// Already in the list, as this book.
        case duplicate(UUID)
        case invalid
    }

    /// The book just scanned a second time: its row is shown highlighted for a moment.
    private(set) var flashing: UUID?
    /// How many times each book has been flashed; a change starts that row's icon bouncing.
    private(set) var flashCounts: [UUID: Int] = [:]
    @ObservationIgnored private var flashBusy = false

    /// Adds an ISBN (ignored if invalid or already in the list) and looks it up.
    @discardableResult
    func add(_ raw: String) -> AddResult {
        guard let isbn = BookLookup.normalizedISBN(raw) else { return .invalid }
        // The same book as ISBN-10 or ISBN-13 is still the same book.
        let key = ISBN.canonical13(isbn) ?? isbn
        if let existing = books.first(where: { (ISBN.canonical13($0.isbn) ?? $0.isbn) == key }) { return .duplicate(existing.id) }
        achievements?.record(isbn)
        books.append(ScannedBook(isbn: isbn))
        lastAdded = isbn
        lookUp(isbn, announce: true)
        return .added
    }

    /// Highlights a book's row for a moment, at most once every 5 seconds: the
    /// camera reports the same barcode on every frame it stays in view.
    func flash(_ id: UUID) {
        guard !flashBusy else { return }
        flashBusy = true
        flashing = id
        flashCounts[id, default: 0] += 1
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            flashing = nil
            try? await Task.sleep(for: .milliseconds(3800))
            flashBusy = false
        }
    }

    func retry(_ id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].state = .looking
        lookUp(books[index].isbn)
    }

    /// Replaces a book's metadata with the user's edits.
    func update(_ id: UUID, with metadata: BookMetadata) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].state = .found(metadata)
        library?.send(metadata)
    }

    func remove(_ ids: Set<UUID>) { books.removeAll { ids.contains($0.id) } }

    func removeAll() { books.removeAll() }

    /// Call after a successful export: those books won't come back at the next launch.
    func markExported() {
        exported.formUnion(books.filter { $0.metadata != nil }.map(\.id))
        save()
    }

    private func save() {
        guard let storeURL else { return }
        ScanStore.save(books.filter { !exported.contains($0.id) }, to: storeURL)
    }

    /// - Parameter announce: say the result aloud for VoiceOver; only for books the user
    ///   just scanned, not ones restored at launch.
    private func lookUp(_ isbn: String, announce: Bool = false) {
        Task {
            let state: ScannedBook.State
            do {
                if let metadata = try await lookupService.lookup(isbn: isbn) {
                    state = .found(metadata)
                    if announce { Announcer.post(metadata.fullTitle) }
                } else {
                    // A book from a language area the catalogues cover poorly says so,
                    // instead of a bare "No match found".
                    let notice = ISBNRegion.notice(forISBN: isbn)
                    state = .failed(notice ?? BookLookup.LookupError.notFound.localizedDescription)
                    if announce { Announcer.post(notice ?? "No details found for \(isbn)", urgent: notice != nil) }
                }
            } catch {
                state = .failed(error.localizedDescription)
                if announce { Announcer.post("Couldn't look up \(isbn)") }
            }
            if let index = books.firstIndex(where: { $0.isbn == isbn }) { books[index].state = state }
            if case .found(let metadata) = state { library?.send(metadata) }
        }
    }
}

/// The books on disk. A book still being looked up (or whose lookup failed) is
/// saved as just its ISBN and looked up again when it's restored.
enum ScanStore {
    private struct Entry: Codable {
        var id: UUID
        var isbn: String
        var metadata: BookMetadata?
    }

    static func save(_ books: [ScannedBook], to url: URL) {
        let entries = books.map { Entry(id: $0.id, isbn: $0.isbn, metadata: $0.metadata) }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: url, options: .atomic)
        } catch {
            // Saving is a safety net; the app keeps working without it.
        }
    }

    static func load(from url: URL) -> [ScannedBook] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries.map { ScannedBook(id: $0.id, isbn: $0.isbn, state: $0.metadata.map { .found($0) } ?? .looking) }
    }
}
