import SwiftUI

// swiftlint:disable line_length

/// The Help window (Help ▸ ElmScanner Help): a short guide to scanning and exporting.
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("ElmScanner Help").font(.largeTitle.bold())
                section("Scan books",
                        "Hold the barcode on a book's back cover up to the camera. ElmScanner reads the ISBN, looks the book up and adds it to the list. You can also type or paste an ISBN under the camera and click Add.")
                section("Check the list",
                        "Click Next to review the books. If a book wasn't found, or a detail is missing, double-click it to enter the details by hand. A book that wasn't found isn't exported until you do.")
                section("Export",
                        "Choose Export, then a format such as RIS or BibTeX; More… has the rest. Import the file into Zotero or another reference manager. Exported books can be scanned again later.")
                section("Your email address",
                        "ElmScanner asks for your email address once, because Open Library asks every app to send one. Change it in Settings (⌘,).")
                section("Books it can't find",
                        "ElmScanner looks books up at Open Library and the National Diet Library, which cover English and Japanese books best. For other languages, enter the details by hand.")
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    private func section(_ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(body).fixedSize(horizontal: false, vertical: true)
        }
    }
}
