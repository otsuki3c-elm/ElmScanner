# App Store listing draft

*Draft text for App Store Connect. Character limits are Apple's; the counts below were checked. The app is free and open source (MIT); a bundle ID of your own goes in `Config/Local.xcconfig`.*

## One app, both platforms (universal purchase)

The Mac and iPhone apps share the bundle ID `com.otsuki.elmscanner.ElmScanner`, so they can live in a single App Store Connect app record: both apps are free. Apple does not allow a bundle ID to change after submission.

1. Create the app record (platform iOS) with that bundle ID.
2. In the same record, click the "+" next to the platform list and add **macOS**. The bundle ID must match.
3. Upload an iOS build and a macOS build (Xcode: Product > Archive, once per scheme). Build numbers are counted separately per platform.
4. Set the price to Free once, for the whole app (no paid-apps agreement or tax forms are needed). Fill in the iPhone and Mac versions' screenshots and review notes separately; the name, privacy policy and price are shared.

## Basics

| Field | Text |
|---|---|
| Name (max 30) | ElmScanner |
| Subtitle (max 30) | Scan book ISBNs, export refs |
| Primary category | Productivity (the project is currently set to this) |
| Secondary category | Reference |
| Price | Free |
| Support URL | [your support page or email page] |
| Privacy policy URL | [where docs/PRIVACY.md is published] |
| Copyright | © 2026 Grant Jun Otsuki (use your legal name if it differs) |

## Promotional text (max 170, can be changed any time)

Point your camera at a book's barcode and add it to your reference list in a second. Export to RIS, BibTeX and 13 other formats.

## Keywords (max 100, comma-separated, no spaces after commas)

isbn,barcode,scanner,books,citation,bibliography,reference,library,bibtex,ris,catalog,research

## Description (max 4000)

ElmScanner turns the barcode on the back of a book into a citation-ready record. Hold the book up to your camera, and the title, author, publisher, year and more are filled in for you. When you're done, export the whole list for your reference manager.

SCAN OR TYPE
• Point the camera at an ISBN barcode in any orientation. A green check confirms a book was recognized; a red X means the barcode wasn't a book.
• Or type an ISBN by hand.
• Scan a book twice and ElmScanner won't add it again. It scrolls to the one you already have.
• Books you've looked up before are remembered on your device, so scanning them again works without an internet connection.

REVIEW AND EDIT
• See exactly what will be exported for every book, with missing details flagged.
• Tap (iPhone) or double-click (Mac) any book to correct or complete it.
• Book details come from Open Library, a project of the Internet Archive.

EXPORT TO MANY FORMATS
• RIS and BibTeX first, then BibLaTeX, CSL JSON, MODS, MARC, MARCXML, EndNote XML, RefWorks, Web of Science, Refer/BibIX, Zotero RDF, Bibliontology RDF, Dublin Core RDF and XML ContextObject.
• These are formats that reference managers such as Zotero can import.
• On iPhone, save to the Files app or send the file by email as an attachment.

NEVER LOSE YOUR LIST (iPHONE)
• Books you've scanned but not yet exported are kept safely, even if the app closes unexpectedly.
• One tap clears the list when you want a fresh start.

EARN RANKS
• As you scan more different books, you reach new ranks, with a little celebration.

FREE AND OPEN SOURCE
• The source code is available under the MIT license.

PRIVATE BY DESIGN
• No account, no ads, no tracking.
• The camera image never leaves your device. Only a book's ISBN is sent to Open Library to look up its details.

ElmScanner works with Zotero's import formats but is not made by or endorsed by Zotero.

## What's New (version 1.0)

First release.

## Screenshots to capture

- iPhone (6.9-inch size): scanning with the green check; the review screen with the export preview; the Export menu; a rank popup with confetti.
- Mac: the scan window with a book list; the review screen; the rank popup.

## App Review notes

ElmScanner reads ISBN barcodes with the camera. If you cannot scan a physical book, type one of these ISBNs into the "Or type an ISBN" field and tap Add:

- 9780441172719 (Dune)
- 9780857073006 (The Search for WondLa)
- 9780061120084 (To Kill a Mockingbird)

Book details are looked up from Open Library, so an internet connection is needed the first time a book is scanned. No sign-in is required. Tap Next to review the books, then Export.

## Export compliance

The app uses only standard HTTPS and a hash, so it's exempt. The apps already declare `ITSAppUsesNonExemptEncryption = NO`.

## Privacy manifest

`Resources/Shared/PrivacyInfo.xcprivacy` is included in both apps. It declares no tracking, no collected data and no required-reason APIs. I checked the Release binaries for those APIs (file timestamps, disk space, boot time, UserDefaults, keyboard info) and found none.

## Open Library

Open Library replied on 3 November 2026 that it does not review or approve individual apps and pointed to its API page. The app follows that page: it identifies itself with a User-Agent and email (3 requests per second allowed; the app stays at 2.5), caches responses, and makes one request per scanned book. Do not add bulk downloading.

## Privacy "nutrition label" suggestion

Nothing is collected for tracking or linked to the user. The ISBN sent to Open Library (with the IP address inherent to any request) is the only data that leaves the device. Review Apple's definitions in App Store Connect and answer accordingly; "Data Not Collected" is the likely answer, but it's your call to confirm.
