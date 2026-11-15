# ElmScanner Privacy Policy

*Draft. Check the effective date, then publish this page at a public web address and enter that address in App Store Connect.*

**Effective date:** 4 November 2026

ElmScanner scans the ISBN barcode on a book, looks up its details, and lets you export a list of books. It has no accounts, no ads, no analytics and no tracking. This page explains what the app does with your information.

## What stays on your device

- **The camera.** ElmScanner uses the camera to read barcodes, and to notice when someone smiles at it so it can say "Hello!" over the preview. Camera images are processed on your device. They are never saved and never sent anywhere, and nothing about a face is kept.
- **Your scanned list (iPhone).** The iPhone app saves the books you have scanned but not yet exported, so a crash or force-quit doesn't lose them. They are stored only on your iPhone, in the app's private storage, and removed from the saved list once you export them or tap Clear.
- **Book details already looked up.** So that scanning the same book again needs no internet connection, the app remembers the details Open Library or the National Diet Library returned (title, authors, publisher, year) for up to 6 months, or 2 weeks for books it could not find. They are stored only on your device, in the app's private storage, and are never sent anywhere. Deleting the app removes them.
- **Your email address.** The first time you use the app, it asks for your email address (you can change it later: Settings on the Mac, About on the iPhone). It is stored only on your device. See "What is sent over the internet" for why it is asked for.
- **Your rank count (iPhone and Mac).** To count how many different books you have scanned, the app keeps a hidden log. For each book it stores only a one-way hash (a scrambled code) of the ISBN, never the ISBN, title or author. The hash can't be turned back into a title, and it is used only to avoid counting the same book twice.
- **Sent to ElmLibrary through your own iCloud.** Unless you turn it off (Settings on the Mac, About on the iPhone), each scanned book's details (title, authors, publisher, year, ISBN) are saved to your private iCloud (CloudKit) so that ElmLibrary can add them to your library. Only you, signed in to your Apple ID, can read them; ElmScanner's author never receives them, and ElmLibrary removes them from iCloud once they are in your library. ElmScanner uses no server of ours.
- **Nothing else is synced.** Deleting the app deletes the data above that is stored on your device.

## What is sent over the internet

- **Book lookups.** To fill in a book's title, author, publisher and other details, ElmScanner sends the book's ISBN to **Open Library** (openlibrary.org, run by the Internet Archive). Open Library asks every app to identify itself and the person using it, so each lookup also carries **the email address you entered** (in the request's User-Agent header, next to the app's own contact address). Like any web request, it reveals your device's IP address to them too. The email address is used by Open Library to tell its users apart and to contact them about problems with their requests; it is not sent to anyone else, and ElmScanner's author never receives it. How Open Library handles requests is described in their own privacy policy.
- **Japanese books.** If a book's ISBN starts with 978-4 (published in Japan), or Open Library doesn't know a book, ElmScanner also asks the **National Diet Library** (NDL Search, ndlsearch.ndl.go.jp) for its details. NDL receives only the book's ISBN, plus your device's IP address like any web request. **Your email address is not sent to NDL.** How NDL handles requests is described on its own website.
- **Nothing else.** The app makes no other network connections.

## Tips

ElmScanner is free, and nothing in it depends on payment. If you choose to leave an optional tip, the purchase is made through Apple's in-app purchase system. Apple handles your payment details and Apple ID; ElmScanner and its author receive no personal information from a tip, and the app doesn't record whether you made one.

The Mac version downloaded from GitHub has no in-app purchase. Its tip section just shows a PayPal address to send to. The app never contacts PayPal and doesn't record whether you tipped; if you send a tip, PayPal's own privacy policy applies.

## Exporting

When you export, the file goes only where you send it: to a location you pick in the Files app or a Mac save dialog, or to an email you send with the Mail app. ElmScanner never uploads your exported file itself.

## Children

ElmScanner doesn't collect personal information from anyone, including children.

## Changes

If this policy changes, the new version will be posted at this address with a new effective date.

## Contact

Grant Jun Otsuki · elmscanner@gjotsuki.net
