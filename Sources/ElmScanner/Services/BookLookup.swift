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

    static func lookup(isbn: String, session: URLSession = .shared) async throws -> BookMetadata {
        guard let isbn = normalizedISBN(isbn) else { throw LookupError.invalidISBN }
        var components = URLComponents(string: "https://openlibrary.org/api/books")!
        components.queryItems = [
            URLQueryItem(name: "bibkeys", value: "ISBN:\(isbn)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "jscmd", value: "data")
        ]
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue("ElmScanner (ISBN scanner)", forHTTPHeaderField: "User-Agent")
        let data: Data
        do {
            let (body, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw LookupError.network("HTTP \(http.statusCode)")
            }
            data = body
        } catch let error as LookupError {
            throw error
        } catch {
            throw LookupError.network(error.localizedDescription)
        }
        guard let metadata = parse(data, isbn: isbn) else { throw LookupError.notFound }
        return metadata
    }

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
