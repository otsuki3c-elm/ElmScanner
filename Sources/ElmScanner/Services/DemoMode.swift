import SwiftUI

/// A debug-only way to start the app with sample books and no camera, so App Store screenshots can be
/// taken without showing a real camera view or anyone's own data. In a Release build every property
/// here is off, so none of it runs for users.
///
/// Launch with the environment variable `ELM_DEMO_SCREEN=<scan|review|edit|about|rank>` and the argument
/// `-openLibraryContactEmail demo@example.com` (so the email prompt stays away).
enum DemoMode {
    #if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments
    private static let environmentScreen = ProcessInfo.processInfo.environment["ELM_DEMO_SCREEN"]
    static var isOn: Bool { environmentScreen != nil || arguments.contains("-demo") }
    static var screen: String {
        if let environmentScreen { return environmentScreen }
        guard let index = arguments.firstIndex(of: "-demoScreen"), arguments.indices.contains(index + 1) else { return "scan" }
        return arguments[index + 1]
    }
    #else
    static var isOn: Bool { false }
    static var screen: String { "scan" }
    #endif

    /// Whether the app should open straight on the review screen.
    static var startsInReview: Bool { isOn && ["review", "edit"].contains(screen) }
    static var opensEditor: Bool { isOn && screen == "edit" }
    static var opensAbout: Bool { isOn && screen == "about" }

    #if DEBUG
    private static func book(_ title: String, _ subtitle: String? = nil, _ authors: [AuthorName], _ publisher: String,
                             _ place: String?, _ year: Int, _ pages: String, _ isbn: String, _ tags: [String] = []) -> ScannedBook {
        ScannedBook(isbn: isbn, state: .found(BookMetadata(
            title: title, subtitle: subtitle, authors: authors, publisher: publisher, place: place, publicationYear: year,
            numberOfPages: pages, isbn: isbn, url: nil, tags: tags)))
    }

    static var books: [ScannedBook] {
        [
            book("Dune", nil, [AuthorName(givenName: "Frank", familyName: "Herbert")], "Ace", nil, 2006, "528", "9780441172719", ["Science fiction"]),
            book("吾輩は猫である", nil, [AuthorName(givenName: "漱石", familyName: "夏目")], "岩波書店", nil, 1990, "563", "9784003101018", ["日本文学"]),
            book("Elefant", "Roman", [AuthorName(givenName: "Martin", familyName: "Suter")], "Diogenes", "Zürich", 2017, "351", "9783257069709"),
            book("Sapiens", "une brève histoire de l'humanité", [AuthorName(givenName: "Yuval Noah", familyName: "Harari")],
                 "Albin Michel", "Paris", 2015, "501", "9782226257017", ["Histoire universelle"]),
            book("Cien años de soledad", nil, [AuthorName(givenName: "Gabriel", familyName: "García Márquez")],
                 "Alfaguara", "Madrid", 2007, "609", "9788420471839"),
            book("To Kill a Mockingbird", nil, [AuthorName(givenName: "Harper", familyName: "Lee")],
                 "Harper Perennial", "New York", 2002, "336", "9780061120084")
        ]
    }

    /// A session holding the sample books, with a rank tracker that touches no real files.
    @MainActor static func makeSession() -> ScanSession {
        let tracker = AchievementTracker(logURL: nil, ranks: Rank.bundled)
        tracker.setDemo(count: 116, showAward: screen == "rank")
        let session = ScanSession(achievements: tracker)
        session.books = books
        return session
    }
    #endif

    /// Stands in for the camera: a book's back cover with a barcode, and the green check.
    static var cameraPlaceholder: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.18), Color(white: 0.06)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 10) {
                Text("ISBN 978-4-00-310101-8").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.black)
                HStack(spacing: 2) {
                    ForEach(Array([3, 1, 2, 1, 4, 1, 1, 3, 2, 1, 1, 2, 3, 1, 2, 4, 1, 1, 2, 1, 3, 2, 1, 1, 4, 1, 2, 3, 1, 1, 2, 1].enumerated()), id: \.offset) { index, width in
                        Rectangle().fill(index.isMultiple(of: 2) ? .black : .clear).frame(width: CGFloat(width) * 2, height: 84)
                    }
                }
            }
            .padding(22)
            .background(Color(red: 0.96, green: 0.94, blue: 0.88), in: RoundedRectangle(cornerRadius: 10))
            .rotationEffect(.degrees(-4))
            .shadow(radius: 12, y: 6)
            if screen == "scan" { ScanFeedbackView(kind: .recognized) }
        }
    }
}
