# App Store listing draft

*Draft text for App Store Connect. Character limits are Apple's; the counts below were checked. The app is free and open source (MIT); a bundle ID of your own goes in `Config/Local.xcconfig`.*

## One app, iPhone and Mac (universal purchase)

The Mac app and the iPhone app share the bundle ID `com.otsuki.elmscanner.ElmScanner`, so they can live in a single App Store Connect app record: both apps are free. Apple does not allow a bundle ID to change after submission.

1. Create the app record (platform iOS) with that bundle ID.
2. In the same record, click the "+" next to the platform list and add **macOS**. The bundle ID must match.
3. Upload an iOS build and a macOS build (Xcode: Product > Archive, once per scheme). Build numbers are counted separately per platform.
4. Set the price to Free once, for the whole app. (The optional tip does need the Paid Apps Agreement, tax and bank details; see "Optional tip" below.) Fill in the iPhone and Mac versions' screenshots and review notes separately; the name, privacy policy and price are shared.

## Basics

| Field | Text |
|---|---|
| Name (max 30) | ElmScanner |
| Subtitle (max 30) | Scan book ISBNs, export refs |
| Primary category | Productivity (the project is currently set to this) |
| Secondary category | Reference |
| Price | Free |
| Support URL | https://github.com/otsuki3c-elm/ElmScanner/issues |
| Privacy policy URL | https://github.com/otsuki3c-elm/ElmScanner/blob/main/docs/PRIVACY.md |
| Copyright | © 2026 Grant Jun Otsuki (use your legal name if it differs) |

## Promotional text (max 170, can be changed any time)

Point your camera at a book's barcode and add it to your reference list in a second. Export to RIS, BibTeX, Excel, CSV and 13 other formats.

## Keywords (max 100, comma-separated, no spaces after commas)

isbn,barcode,scanner,books,citation,bibliography,reference,library,bibtex,ris,catalog,research

## Description (max 4000)

ElmScanner turns the barcode on the back of a book into a citation-ready record. Hold the book up to your camera, and the title, author, publisher, year and more are filled in for you. When you're done, export the whole list for your reference manager.

SCAN OR TYPE
• Point the camera at an ISBN barcode in any orientation. On iPhone it starts on the back camera, with a button to switch; on the Mac you can choose among connected cameras. A green check confirms a book was recognized; a red X means the barcode wasn't a book.
• Or type an ISBN by hand.
• Scan a book twice and ElmScanner won't add it again. It scrolls to the one you already have.
• Books you've looked up before are remembered on your device, so scanning them again works without an internet connection.

REVIEW AND EDIT
• See exactly what will be exported for every book, with missing details flagged.
• Tap (iPhone) or double-click (Mac) any book to correct or complete it.
• Book details come from Open Library (a project of the Internet Archive) and from the national libraries of Japan (NDL Search), Germany (Deutsche Nationalbibliothek), France (Bibliothèque nationale de France) and Spain (Biblioteca Nacional de España) for books in those languages.

EXPORT TO MANY FORMATS
• RIS, BibTeX, Excel (.xlsx) and CSV first, then BibLaTeX, CSL JSON, MODS, MARC, MARCXML, EndNote XML, RefWorks, Web of Science, Refer/BibIX, Zotero RDF, Bibliontology RDF, Dublin Core RDF and XML ContextObject.
• These are formats that reference managers such as Zotero can import.
• Keep one running Excel list: choose an Excel or CSV file you exported earlier and the new books are added to the end (books already in it are skipped).
• On iPhone, save to the Files app or send the file by email as an attachment.

NEVER LOSE YOUR LIST (iPHONE)
• Books you've scanned but not yet exported are kept safely, even if the app closes unexpectedly.
• One tap clears the list when you want a fresh start.

EARN RANKS
• As you scan more different books, you reach new ranks, from Beginner up to Little Bookstore on the Corner, with a little celebration.

A FRIENDLY LITTLE EXTRA
• Smile at the camera and ElmScanner says hello. It's all on your device; nothing about a face is saved or sent.

ENGLISH AND JAPANESE
• Fully localized in English and Japanese, including Japanese book lookups.

FREE AND OPEN SOURCE
• The source code is available under the MIT license.

PRIVATE BY DESIGN
• No account, no ads, no tracking.
• The camera image never leaves your device (smile detection runs on the device too). Only a book's ISBN goes to Open Library or, for Japanese, German, French and Spanish books, the national library of that country, to look up its details; your email address (which Open Library asks every app to send) goes to Open Library only.

ElmScanner works with Zotero's import formats but is not made by or endorsed by Zotero.

## 日本語 (Japanese listing)

| Field | Text |
|---|---|
| Name | ElmScanner |
| Subtitle (max 30) | 書籍バーコードで文献リスト作成 |
| Keywords (max 100) | ISBN,バーコード,スキャナ,本,書籍,文献,引用,参考文献,蔵書,図書,BibTeX,RIS,Zotero |

**Promotional text:** 本のバーコードにカメラを向けるだけで、文献リストに追加。RIS・BibTeX・Excel・CSVなど17形式で書き出せます。

**Description:**

ElmScannerは、本の裏表紙のバーコードを、そのまま文献情報に変えるアプリです。本をカメラにかざすと、書名・著者・出版社・出版年などが自動で入力されます。スキャンが終わったら、リスト全体を文献管理ソフトに書き出せます。

スキャンまたは手入力
• ISBNバーコードにカメラを向けるだけ。書籍と認識されると緑のチェック、書籍以外のバーコードだと赤い×が表示されます。
• ISBNを手入力することもできます。
• 同じ本を2回スキャンしても重複して追加されません。すでにリストにある本が表示されます。
• 一度調べた本は端末に記憶されるので、次回はオフラインでもスキャンできます。
• iPhoneは背面カメラで起動し、ボタンで切り替え可能。Macでは接続中のカメラから選べます。

確認と編集
• 書き出す内容を本ごとに確認でき、不足している情報には印が付きます。
• iPhoneはタップ、Macはダブルクリックで、内容を修正・補完できます。
• 書籍情報はOpen Library(Internet Archive)から取得します。日本・ドイツ・フランス・スペインの本は、それぞれの国立図書館（国立国会図書館サーチ、ドイツ国立図書館、フランス国立図書館、スペイン国立図書館）からも取得します。

多彩な形式で書き出し
• RIS、BibTeX、Excel（.xlsx）、CSVのほか、BibLaTeX、CSL JSON、MODS、MARC、MARCXML、EndNote XML、RefWorks、Web of Science、Refer/BibIX、Zotero RDF、Bibliontology RDF、Dublin Core RDF、XML ContextObjectに対応。
• Zoteroなどの文献管理ソフトで読み込める形式です。
• 以前書き出したExcelまたはCSVファイルを選ぶと、新しい本が末尾に追加されます（すでに入っている本は追加されません）。
• iPhoneでは「ファイル」への保存やメール添付で書き出せます。

リストが消えません(iPhone)
• 書き出す前のスキャン結果は、アプリが突然終了しても保存されています。

ランクを集めよう
• 異なる本をスキャンするほどランクが上がり、ちょっとしたお祝いが表示されます。

ちょっとした楽しみ
• カメラに向かって笑うと、ElmScannerがあいさつします。処理はすべて端末内で行われ、顔の情報が保存・送信されることはありません。

無料・オープンソース
• ソースコードはMITライセンスで公開されています。

プライバシーに配慮
• アカウント登録、広告、トラッキングは一切ありません。
• カメラの映像は端末の外に出ません。書籍情報の取得のため、ISBNがOpen Libraryまたは(日本の本の場合)国立国会図書館に送信されます。メールアドレス(Open Libraryがすべてのアプリに求めるもの)はOpen Libraryにのみ送信されます。

ElmScannerはZoteroの読み込み形式に対応していますが、Zotero社が提供・承認したものではありません。

**What's New:** 初めてのリリースです。

## What's New (version 1.0)

First release.

## Screenshots to capture

- iPhone (6.9-inch size): scanning with the green check; the review screen with the export preview; the Export menu; a rank popup with confetti.
- (iPad is on hold: no iPad screenshots are needed until the iPad version ships.)
- Shoot Japanese-language sets too (the Japanese listing can reuse the English shots, or use Japanese ones for a better look).
- Mac: the scan window with a book list; the review screen; the rank popup.

## App Review notes

ElmScanner reads ISBN barcodes with the camera (it also shows a greeting if the camera sees a smile; this runs on the device and nothing is stored). It runs on iPhone and Mac. If you cannot scan a physical book, type one of these ISBNs into the "Or type an ISBN" field and tap Add:

- 9780441172719 (Dune)
- 9780857073006 (The Search for WondLa)
- 9780061120084 (To Kill a Mockingbird)

Book details are looked up from Open Library or, for Japanese ISBNs (such as 9784003101018, 吾輩は猫である), German ISBNs (such as 9783257069709, Elefant), French ISBNs (such as 9782226257017, Sapiens) and Spanish ISBNs (such as 9788420471839, Cien años de soledad), the national library of that country, so an internet connection is needed the first time a book is scanned. No sign-in is required, but the app asks for an email address at first use (any address works; see below). Tap Next to review the books, then Export.

## Export compliance

The app uses only standard HTTPS and a hash, so it's exempt. The apps already declare `ITSAppUsesNonExemptEncryption = NO`.

## Optional tip (in-app purchase)

A single consumable in-app purchase lets users leave a tip. No feature depends on it.

1. In App Store Connect, open the app, then Monetization > In-App Purchases, and create a **Consumable**.
2. **Product ID:** the bundle ID plus `.tip`, for example `com.otsuki.elmscanner.ElmScanner.tip`. It must match exactly.
3. **Reference name** "Tip"; **display name** "Tip"; **description** "A one-time tip to support ElmScanner's development. Nothing in the app depends on it." Pick a price point (the local test file uses 3.99 USD).
4. Add the screenshot Apple asks for (the Settings window on the Mac, or the About sheet on the iPhone), then submit the purchase together with the app's first version. Both the Mac and iPhone apps share the product.
5. The Paid Apps Agreement, tax and bank details are needed before it can be sold, even though the app itself is free.

Apple's rules allow in-app purchases as tips for the developer. The app calls it a "tip" and not a donation on purpose: donations to charities must go through approved non-profits. In the app's text, don't suggest the money goes to a charity or unlocks anything.

App Review note: "The Leave a tip button (Settings on Mac, About on iPhone) is an optional consumable purchase. No feature of the app depends on it."

To try it without App Store Connect, run the app from Xcode: the scheme uses `Config/ElmScanner.storekit`.

## Privacy manifest

`Resources/Shared/PrivacyInfo.xcprivacy` is included in both apps. It declares no tracking, no collected data and no required-reason APIs. I checked the Release binaries for those APIs (file timestamps, disk space, boot time, UserDefaults, keyboard info) and found none.

## National Diet Library (NDL Search)

NDL's [API page](https://ndlsearch.ndl.go.jp/help/api) says: individuals and non-profits earning no revenue need no application; an app must state that it uses the NDL Search API (the About screens and README do); and continuing users are asked to send NDL their contact and usage details through its form. There is no published numeric limit, only a limit on simultaneous requests, so the app asks for one lookup a second and waits when told "too many requests". Submit the contact form once before release.

## Deutsche Nationalbibliothek, Bibliothèque nationale de France and Biblioteca Nacional de España

All three are asked through their public search interfaces (SRU), which need no key or sign-up; the app sends one request a second to each and no personal information, and credits them in the About screens and README. Checked on their sites: the DNB's title data is CC0 (no attribution needed), and its SRU page says access is free and needs no registration. The BnF's records are under the Licence Ouverte v2.0, which asks for the source and the date: the app credits the BnF in About and adds a note to each BnF record ("Source: Bibliothèque nationale de France …, retrieved <date>"), which is exported in the formats that have a note field and in the Note column of the Excel and CSV files. For the BNE, its linked-data portal (datos.bne.es) is published under CC0 and its reuse plan rests on Spain's public-sector reuse law, but its website blocked my check of the SRU service's own terms, so confirm them before release. The BNE holds one record per printing and reuses ISBNs across printings, so the app takes the most recent. The BnF finds some older books by ISBN-10 only, so the app searches for both forms, and the DNB answer is checked to be for the right ISBN, since its search can also match related editions.

## Other regions (checked 16 November 2026)

- **Canada, Australia, New Zealand:** English-language books share ISBN groups 0 and 1 with the USA and UK, so Open Library already serves them. Quebec books (group 2) go to the BnF first, then Open Library. No open web interface was found for Library and Archives Canada (Z39.50 only); Australia's Trove needs an API key; nothing found for New Zealand.
- **China:** no open national-library interface found. Open Library answers, but often without place or page count.
- **Latin America:** no open national-library interface found for Mexico, Argentina, Chile, Colombia or Peru. Brazil has BrasilAPI, a community service that combines the Brazilian ISBN agency, Open Library and Google Books (free, no key, but not an official library service). Open Library has the author, publisher and year for most books from these countries sampled, with place and pages patchy (Mexico especially).
- **South Asia (India, Pakistan, Bangladesh, Sri Lanka, Nepal):** no public ISBN lookup interface found for the national ISBN agencies or libraries. Open Library answers with author, publisher and year for most books sampled; place of publication is often missing.
- **Google Books** would be the general fallback for all of these, but its free keyless quota was already used up for the day when I tried it, so it would need an API key of its own.

## Open Library

Open Library replied on 3 November 2026 that it does not review or approve individual apps and pointed to its API page. The app follows that page: it identifies itself with a User-Agent and email (3 requests per second allowed; the app stays at 2.5), caches responses, and makes one request per scanned book. Do not add bulk downloading.

## Privacy "nutrition label" suggestion

Nothing is used for tracking. The ISBN is sent to Open Library and, for Japanese, German, French and Spanish books, the national library of that country (the National Diet Library, Deutsche Nationalbibliothek, Bibliothèque nationale de France or Biblioteca Nacional de España), and the user's email address to Open Library only (third parties), along with the IP address inherent to any request. Because the email address leaves the device, "Data Not Collected" is probably no longer the right answer: read Apple's definitions in App Store Connect and consider declaring **Contact Info > Email Address**, used for App Functionality, not for tracking. This is your call to confirm.

App Review notes: the app asks for an email address at first use. Enter any address (for example review@example.com) to continue. It is only passed to Open Library, as the explanation on screen says.
