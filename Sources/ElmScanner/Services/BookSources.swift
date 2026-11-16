import Foundation

/// The credit for where book details come from, shown in both About screens. Each national
/// library is named for the books of its own country; Open Library covers everything else.
enum BookSources {
    static var credit: String {
        // swiftlint:disable:next line_length
        String(localized: "Book data from:\nOpen Library (Internet Archive): worldwide\nNational Diet Library (NDL Search): Japan\nDeutsche Nationalbibliothek: Germany\nBibliothèque nationale de France (Licence Ouverte): France\nBiblioteca Nacional de España: Spain")
    }
}
