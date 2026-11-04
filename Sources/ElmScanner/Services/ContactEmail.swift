import Foundation
import Observation

/// The user's own email address. Open Library asks every app to put a contact address in
/// its requests, so it can reach whoever is using the service; the app asks for it at
/// first use and sends it only in the `User-Agent` of those requests.
@Observable
@MainActor
final class ContactEmail {
    static let shared = ContactEmail()
    private static let key = "openLibraryContactEmail"

    private(set) var address: String

    init() { address = UserDefaults.standard.string(forKey: Self.key) ?? "" }

    /// True once a usable address has been saved.
    var isSet: Bool { Self.isValid(address) }

    /// Saves the address; returns false (and saves nothing) if it isn't usable.
    @discardableResult
    func save(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValid(trimmed) else { return false }
        address = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.key)
        return true
    }

    /// The saved address, readable from any thread; nil if none.
    nonisolated static func stored() -> String? {
        UserDefaults.standard.string(forKey: key).flatMap { isValid($0) ? $0 : nil }
    }

    /// A plain `name@domain.tld`. Whitespace and the characters that would break a
    /// header (parentheses, semicolons, commas, angle brackets) are not allowed.
    nonisolated static func isValid(_ text: String) -> Bool {
        text.range(of: #"^[^@\s,;()<>]+@[^@\s,;()<>]+\.[^@\s,;()<>.]+$"#, options: .regularExpression) != nil
    }
}
