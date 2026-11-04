# ElmScanner

Scan the ISBN barcode on a book, and ElmScanner fills in its title, authors, publisher and year. Export the list for your reference manager (Zotero and others) as RIS, BibTeX and 13 other formats.

- **Mac:** a SwiftUI app (macOS 14 or later). Scan with the camera or type an ISBN, review the list, then export through a save dialog.
- **iPhone:** a SwiftUI app (iOS 17 or later). Export through the Files app or as an email attachment. Books you haven't exported are kept if the app closes.
- Book details come from [Open Library](https://openlibrary.org) and are remembered on the device, so a book you've already scanned works offline.
- No account, no ads, no analytics. See [docs/PRIVACY.md](docs/PRIVACY.md).

## Build

You need Xcode 15 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
open ElmScanner.xcodeproj
```

The Xcode project is generated from `project.yml` and isn't checked in. There are two apps, **ElmScanner** (Mac) and **ElmScannerPhone** (iPhone). Run the tests with the ElmScanner scheme.

### Signing and bundle ID

The defaults in `Config/Signing.xcconfig` have no developer team and a placeholder bundle ID, which is enough to build and run on the Mac. To run on a real iPhone, or to publish:

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` (git ignores it).
2. Put in your own team ID and your own bundle ID.
3. Run `xcodegen generate` again.

### If you fork this

- **Change the Open Library contact address** in `Sources/ElmScanner/Services/BookLookup.swift` (`contactAddress`). Open Library asks apps to identify themselves, and it holds whoever is named responsible for the traffic. The code keeps within their published limits. Please keep it that way.
- Use your own app name and icon if you publish your own version. The app icon was generated with AI.
- `Resources/Shared/Ranks.json` holds the text for the achievement ranks. Edit it freely.

## How it works

- `Sources/ElmScanner/Services`: barcode reading (Vision), the lookup and its on-device cache, the export writers, and the hashed scan log used for ranks.
- The 15 export formats are written to match what Zotero's importers accept. They were written from the format specifications and were checked against Zotero's translators for compatibility only; no Zotero code is included.

## Credits

Prompted by Grant Jun Otsuki. Code by Claude. Book data from Open Library.

## License

[MIT](LICENSE). The license covers the source code. The ElmScanner name and the app icon are not part of that grant; please use your own for a different app.
