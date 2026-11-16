# ElmScanner

Scan the ISBN barcode on a book, and ElmScanner fills in its title, authors, publisher and year. Export the list for your reference manager (Zotero and others) as RIS, BibTeX and 13 other formats.

- **Mac:** a SwiftUI app (macOS 14 or later). Scan with the camera or type an ISBN, review the list, then export through a save dialog.
- **iPhone:** a SwiftUI app (iOS 17 or later). Export through the Files app or as an email attachment. Books you haven't exported are kept if the app closes.
- Book details come from [Open Library](https://openlibrary.org) and from three national libraries, each asked first for its own language: Japanese books (ISBNs starting 978-4) from the [National Diet Library](https://ndlsearch.ndl.go.jp) (NDL Search), German books (978-3) from the [Deutsche Nationalbibliothek](https://www.dnb.de), French books (978-2 and 979-10) from the [Bibliothèque nationale de France](https://catalogue.bnf.fr) (Licence Ouverte; the exported record carries a note with the source and the date it was taken), and Spanish books (978-84) from the [Biblioteca Nacional de España](https://www.bne.es). Open Library is the fallback for them, and every other book is asked of Open Library first. Answers are remembered on the device, so a book you've already scanned works offline.
- No account, no ads, no analytics. See [docs/PRIVACY.md](docs/PRIVACY.md).

## Build

You need Xcode 15 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
open ElmScanner.xcodeproj
```

The Xcode project is generated from `project.yml` and isn't checked in. There are three apps: **ElmScanner** (Mac, App Store build, tips through In-App Purchase), **ElmScannerDirect** (Mac, for direct download, tips by showing a PayPal address; built with the `DIRECT_DOWNLOAD` flag) and **ElmScannerPhone** (iPhone, App Store only). Run the tests with the ElmScanner scheme.

### Signing and bundle ID

The defaults in `Config/Signing.xcconfig` have no developer team and a placeholder bundle ID, which is enough to build and run on the Mac. To run on a real iPhone, or to publish:

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` (git ignores it).
2. Put in your own team ID and your own bundle ID.
3. Run `xcodegen generate` again.

### If you fork this

- **Change the Open Library contact address** in `Sources/ElmScanner/Services/BookLookup.swift` (`contactAddress`). Open Library asks apps to identify themselves, and it holds whoever is named responsible for the traffic. The code keeps within their published limits. Please keep it that way.
- NDL Search asks apps that use its API to say so (the About screens and this README do), and to send its form to tell NDL about continuing use. The app asks for one lookup a second and waits when NDL says it is busy.
- The German, French and Spanish lookups use the national libraries' public search interfaces (SRU), which need no key. The app sends one request a second to each and no personal information.
- If you fork the direct-download build, change the PayPal address in `Sources/ElmScanner/Views/PayPalTipSection.swift`.
- The optional "Leave a tip" purchase is a consumable in-app purchase whose product ID is your bundle ID plus `.tip`. `Config/ElmScanner.storekit` (used when running from Xcode) has the default one; change its `productID` to match yours. Without a product in App Store Connect the button just says tips aren't available.
- The app also asks each user for their own email address at first use and adds it to the `User-Agent`, as Open Library requests. Nothing is looked up until it is entered.
- Use your own app name and icon if you publish your own version. The app icon was generated with AI.
- `Resources/Shared/Ranks.json` holds the text for the achievement ranks. Edit it freely; the Japanese for each title and message is in `Localizable.xcstrings`.

## How it works

- `Sources/ElmScanner/Services`: barcode reading (Vision), the lookup and its on-device cache, the export writers, and the hashed scan log used for ranks.
- The 15 export formats are written to match what Zotero's importers accept. They were written from the format specifications and were checked against Zotero's translators for compatibility only; no Zotero code is included.

## Credits

Prompted by Grant Jun Otsuki. Code by Claude. Book data from Open Library, the National Diet Library (NDL Search), the Deutsche Nationalbibliothek, the Bibliothèque nationale de France (Licence Ouverte) and the Biblioteca Nacional de España; this app uses the NDL Search API.

## License

[MIT](LICENSE). The license covers the source code. The ElmScanner name and the app icon are not part of that grant; please use your own for a different app.
