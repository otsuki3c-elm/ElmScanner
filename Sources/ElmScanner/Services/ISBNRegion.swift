import Foundation

/// Which language area an ISBN was issued in. The digits after 978/979 are the "registration
/// group", assigned to a country or language area, so they say where a book was published
/// and roughly what language it is in. The catalogues the app asks cover English and
/// Japanese books well and others only patchily.
enum ISBNRegion {
    /// Registration groups the app looks up reliably: English (0, 1, and 979-8 for the USA)
    /// and Japanese (4).
    private static let covered: Set<String> = ["0", "1", "4", "8"]

    /// Groups I'm sure of, named by language (or the language area).
    private static let names: [String: String] = [
        "2": "French", "3": "German", "5": "Russian", "7": "Chinese",
        "80": "Czech and Slovak", "82": "Norwegian", "83": "Polish", "84": "Spanish",
        "85": "Brazilian Portuguese", "87": "Danish", "88": "Italian", "89": "Korean",
        "90": "Dutch", "91": "Swedish", "94": "Dutch",
        "951": "Finnish", "952": "Finnish", "954": "Bulgarian", "957": "Chinese (Taiwan)",
        "960": "Greek", "962": "Chinese (Hong Kong)", "963": "Hungarian", "965": "Hebrew",
        "966": "Ukrainian", "972": "Portuguese", "973": "Romanian", "974": "Thai",
        "975": "Turkish", "986": "Chinese (Taiwan)", "989": "Portuguese",
    ]
    private static let names979: [String: String] = ["10": "French", "11": "Korean", "12": "Italian"]

    /// The registration group of an ISBN-13 ("4" for 978-4-…), or nil if it can't be told.
    static func group(ofISBN13 isbn: String) -> String? {
        guard isbn.count == 13, isbn.allSatisfy(\.isNumber) else { return nil }
        let prefix = isbn.prefix(3)
        let rest = isbn.dropFirst(3)
        if prefix == "979" {
            // 979-8 is the USA; 979-10 France, -11 Korea, -12 Italy.
            if rest.hasPrefix("8") { return "8" }
            return names979.keys.first { rest.hasPrefix($0) }
        }
        guard prefix == "978", let first = rest.first else { return nil }
        switch first {
        case "0", "1", "2", "3", "4", "5", "7": return String(first)
        case "8": return String(rest.prefix(2))
        case "6": return String(rest.prefix(3))
        case "9":
            guard let second = rest.dropFirst().first else { return nil }
            if "01234".contains(second) { return String(rest.prefix(2)) }   // 90–94
            if "5678".contains(second) { return String(rest.prefix(3)) }    // 95x–98x
            return nil                                                       // 99…: small groups
        default: return nil
        }
    }

    /// True when the ISBN is from an English-language or Japanese area (or can't be placed).
    static func isCovered(isbn13: String) -> Bool {
        guard let group = group(ofISBN13: isbn13) else { return true }
        return covered.contains(group)
    }

    /// A notice for the user when the book is from outside the covered areas, else nil.
    static func notice(forISBN isbn: String) -> String? {
        guard let isbn13 = ISBN.canonical13(isbn), !isCovered(isbn13: isbn13),
              let group = group(ofISBN13: isbn13) else { return nil }
        let area = isbn13.hasPrefix("979") ? names979[group] : names[group]
        let place = area.map { "the \($0)-language area" } ?? "a region outside the English- and Japanese-language areas"
        return "No match found. This ISBN is from \(place), and ElmScanner's catalogues cover English and Japanese books best. You can enter the details by hand."
    }
}
