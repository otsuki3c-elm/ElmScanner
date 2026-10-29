import Foundation

/// A person's name split into given/family parts. Organizational authors
/// live entirely in the family name.
struct AuthorName: Hashable {
    var givenName: String = ""
    var familyName: String

    var isOrganization: Bool { givenName.isEmpty }

    /// "Frank Herbert" → Frank / Herbert; "Herbert, Frank" → Frank / Herbert;
    /// a single word goes in the family name.
    init(parsing full: String) {
        let trimmed = full.trimmingCharacters(in: .whitespaces)
        if let comma = trimmed.firstIndex(of: ",") {
            givenName = trimmed[trimmed.index(after: comma)...].trimmingCharacters(in: .whitespaces)
            familyName = String(trimmed[..<comma]).trimmingCharacters(in: .whitespaces)
            return
        }
        let words = trimmed.split(separator: " ")
        if words.count > 1 {
            givenName = words.dropLast().joined(separator: " ")
            familyName = String(words.last!)
        } else {
            familyName = trimmed
        }
    }

    init(givenName: String = "", familyName: String) {
        self.givenName = givenName
        self.familyName = familyName
    }
}

/// What an online lookup found for one ISBN.
struct BookMetadata: Equatable {
    var title: String
    var subtitle: String?
    var authors: [AuthorName]
    var publisher: String?
    var place: String?
    var publicationYear: Int?
    var numberOfPages: String?
    var isbn: String
    var url: String?
    var tags: [String]

    /// Zotero has no subtitle field; "Title: Subtitle" is its convention.
    var fullTitle: String {
        guard let subtitle, !subtitle.isEmpty else { return title }
        return "\(title): \(subtitle)"
    }
}

/// One row in the scan list.
struct ScannedBook: Identifiable {
    enum State {
        case looking
        case found(BookMetadata)
        case failed(String)
    }

    let id = UUID()
    let isbn: String
    var state: State = .looking

    var metadata: BookMetadata? {
        if case .found(let metadata) = state { return metadata }
        return nil
    }
}
