import Foundation
import Observation

/// The list of scanned books: each new ISBN is added once and looked up.
@Observable
@MainActor
final class ScanSession {
    var books: [ScannedBook] = []
    /// The ISBN most recently added, for a brief highlight in the UI.
    var lastAdded: String?

    var foundBooks: [BookMetadata] { books.compactMap(\.metadata) }

    /// Adds an ISBN (ignored if invalid or already in the list) and looks it up.
    func add(_ raw: String) {
        guard let isbn = BookLookup.normalizedISBN(raw), !books.contains(where: { $0.isbn == isbn }) else { return }
        books.append(ScannedBook(isbn: isbn))
        lastAdded = isbn
        lookUp(isbn)
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
    }

    func remove(_ ids: Set<UUID>) { books.removeAll { ids.contains($0.id) } }

    private func lookUp(_ isbn: String) {
        Task {
            let state: ScannedBook.State
            do {
                state = .found(try await BookLookup.lookup(isbn: isbn))
            } catch {
                state = .failed(error.localizedDescription)
            }
            if let index = books.firstIndex(where: { $0.isbn == isbn }) { books[index].state = state }
        }
    }
}
