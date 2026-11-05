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
• Book details come from Open Library (a project of the Internet Archive) and, for Japanese books, the National Diet Library's NDL Search.

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
• The camera image never leaves your device. Only a book's ISBN goes to Open Library or, for Japanese books, the National Diet Library, to look up its details; your email address (which Open Library asks every app to send) goes to Open Library only.

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

Book details are looked up from Open Library or, for Japanese ISBNs (such as 9784003101018, 吾輩は猫である), the National Diet Library, so an internet connection is needed the first time a book is scanned. No sign-in is required, but the app asks for an email address at first use (any address works; see below). Tap Next to review the books, then Export.

## Export compliance

The app uses only standard HTTPS and a hash, so it's exempt. The apps already declare `ITSAppUsesNonExemptEncryption = NO`.

## Optional tip (in-app purchase)

A single consumable in-app purchase lets users leave a tip. No feature depends on it.

1. In App Store Connect, open the app, then Monetization > In-App Purchases, and create a **Consumable**.
2. **Product ID:** the bundle ID plus `.tip`, for example `com.otsuki.elmscanner.ElmScanner.tip`. It must match exactly.
3. **Reference name** "Tip"; **display name** "Tip"; **description** "A one-time tip to support ElmScanner's development. Nothing in the app depends on it." Pick a price point (the local test file uses 0.99 USD).
4. Add the screenshot Apple asks for (the Settings window on the Mac, or the About sheet on the iPhone), then submit the purchase together with the app's first version. Both the Mac and iPhone apps share the product.
5. The Paid Apps Agreement, tax and bank details are needed before it can be sold, even though the app itself is free.

Apple's rules allow in-app purchases as tips for the developer. The app calls it a "tip" and not a donation on purpose: donations to charities must go through approved non-profits. In the app's text, don't suggest the money goes to a charity or unlocks anything.

App Review note: "The Leave a tip button (Settings on Mac, About on iPhone) is an optional consumable purchase. No feature of the app depends on it."

To try it without App Store Connect, run the app from Xcode: the scheme uses `Config/ElmScanner.storekit`.

## Privacy manifest

`Resources/Shared/PrivacyInfo.xcprivacy` is included in both apps. It declares no tracking, no collected data and no required-reason APIs. I checked the Release binaries for those APIs (file timestamps, disk space, boot time, UserDefaults, keyboard info) and found none.

## National Diet Library (NDL Search)

NDL's [API page](https://ndlsearch.ndl.go.jp/help/api) says: individuals and non-profits earning no revenue need no application; an app must state that it uses the NDL Search API (the About screens and README do); and continuing users are asked to send NDL their contact and usage details through its form. There is no published numeric limit, only a limit on simultaneous requests, so the app asks for one lookup a second and waits when told "too many requests". Submit the contact form once before release.

## Open Library

Open Library replied on 3 November 2026 that it does not review or approve individual apps and pointed to its API page. The app follows that page: it identifies itself with a User-Agent and email (3 requests per second allowed; the app stays at 2.5), caches responses, and makes one request per scanned book. Do not add bulk downloading.

## Privacy "nutrition label" suggestion

Nothing is used for tracking. The ISBN is sent to Open Library and the National Diet Library, and the user's email address to Open Library only (third parties), along with the IP address inherent to any request. Because the email address leaves the device, "Data Not Collected" is probably no longer the right answer: read Apple's definitions in App Store Connect and consider declaring **Contact Info > Email Address**, used for App Functionality, not for tracking. This is your call to confirm.

App Review notes: the app asks for an email address at first use. Enter any address (for example review@example.com) to continue. It is only passed to Open Library, as the explanation on screen says.
