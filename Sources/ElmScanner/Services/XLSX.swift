// swiftlint:disable line_length   (the XML parts are single-line literals)
import Compression
import Foundation

/// Writes books to an Excel workbook (.xlsx), or adds them to one made earlier.
///
/// An .xlsx file is a zip of XML parts. Making one needs a zip writer; adding to one also needs
/// a zip reader, and every part other than the sheet is copied across byte for byte, so
/// whatever else the workbook holds (other sheets, formatting, formulas) is left alone.
enum XLSX {
    /// The columns, in order. They stay in English so files from any language line up.
    static let headers = [
        "Title", "Subtitle", "Authors", "Publisher", "Place of Publication", "Year", "Pages", "ISBN", "URL", "Tags", "Note"
    ]

    enum Failure: LocalizedError {
        /// Not a zip, or not a workbook we can read (an old .xls, a password-protected file…).
        case notWorkbook
        /// The first sheet has data but not ElmScanner's columns.
        case noColumns

        var errorDescription: String? {
            switch self {
            case .notWorkbook:
                return String(localized: "That isn't an Excel workbook (.xlsx) that ElmScanner can read. Older .xls files and password-protected files can't be used.")
            case .noColumns:
                return String(localized: "The first sheet doesn't have ElmScanner's columns (Title, Authors, ISBN…). Choose a file exported from ElmScanner, or an empty workbook.")
            }
        }
    }

    // MARK: Cells

    private enum Cell {
        case text(String)
        case number(Int)
    }

    /// The book's values as plain text, in the order of `headers` (empty where there is none).
    static func values(for book: BookMetadata) -> [String] {
        cells(for: book).map {
            switch $0 {
            case .text(let text): return text
            case .number(let number): return String(number)
            case nil: return ""
            }
        }
    }

    private static func cells(for book: BookMetadata) -> [Cell?] {
        func text(_ value: String?) -> Cell? {
            guard let value, !value.isEmpty else { return nil }
            return .text(value)
        }
        let authors = book.authors
            .map { $0.isOrganization ? $0.familyName : "\($0.familyName), \($0.givenName)" }
            .joined(separator: "; ")
        return [
            text(book.title), text(book.subtitle), text(authors), text(book.publisher), text(book.place),
            book.publicationYear.map { .number($0) }, text(book.numberOfPages), text(book.isbn), text(book.url),
            text(book.tags.joined(separator: ", ")), text(book.note)
        ]
    }

    /// "A", "B", … "Z", "AA"… for a zero-based column.
    private static func letters(_ column: Int) -> String {
        var number = column + 1
        var result = ""
        while number > 0 {
            number -= 1
            result = String(UnicodeScalar(UInt8(65 + number % 26))) + result
            number /= 26
        }
        return result
    }

    /// The zero-based column of a reference like "C7".
    private static func column(of reference: String) -> Int {
        var value = 0
        for scalar in reference.unicodeScalars {
            guard scalar.value >= 65, scalar.value <= 90 else { break }
            value = value * 26 + Int(scalar.value) - 64
        }
        return max(value - 1, 0)
    }

    /// XML text: escapes the markup characters and drops characters XML can't hold at all.
    private static func escape(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "\t", "\n", "\r": out.unicodeScalars.append(scalar)
            default:
                if scalar.value >= 0x20, scalar.value != 0xFFFE, scalar.value != 0xFFFF,
                   !(0xD800...0xDFFF).contains(scalar.value) {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }

    private static func xml(_ cell: Cell, at reference: String, style: Int? = nil) -> String {
        let styleAttribute = style.map { " s=\"\($0)\"" } ?? ""
        switch cell {
        case .text(let text):
            return "<c r=\"\(reference)\"\(styleAttribute) t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(text))</t></is></c>"
        case .number(let number):
            return "<c r=\"\(reference)\"\(styleAttribute)><v>\(number)</v></c>"
        }
    }

    /// One `<row>`; `columns[i]` is the sheet column that `values[i]` goes into.
    private static func row(_ number: Int, columns: [Int], values: [Cell?], style: Int? = nil) -> String {
        let cells = zip(columns, values).sorted { $0.0 < $1.0 }.compactMap { column, value in
            value.map { xml($0, at: "\(letters(column))\(number)", style: style) }
        }
        return "<row r=\"\(number)\">\(cells.joined())</row>"
    }

    // MARK: A new workbook

    static func create(_ books: [BookMetadata]) throws -> Data {
        let columns = Array(headers.indices)
        var rows = [row(1, columns: columns, values: headers.map { .text($0) }, style: 1)]
        for (index, book) in books.enumerated() {
            rows.append(row(index + 2, columns: columns, values: cells(for: book)))
        }
        let widths = [40, 24, 32, 28, 22, 8, 8, 16, 36, 24, 48]
        let cols = widths.enumerated().map { "<col min=\"\($0 + 1)\" max=\"\($0 + 1)\" width=\"\($1)\" customWidth=\"1\"/>" }.joined()
        let sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:\(letters(headers.count - 1))\(books.count + 1)"/><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols>\(cols)</cols><sheetData>\(rows.joined())</sheetData></worksheet>
        """
        let main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let parts: [(String, String)] = [
            ("[Content_Types].xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>
            """),
            ("_rels/.rels", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="\(rel)/officeDocument" Target="xl/workbook.xml"/></Relationships>
            """),
            ("xl/workbook.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <workbook xmlns="\(main)" xmlns:r="\(rel)"><sheets><sheet name="Books" sheetId="1" r:id="rId1"/></sheets></workbook>
            """),
            ("xl/_rels/workbook.xml.rels", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="\(rel)/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="\(rel)/styles" Target="styles.xml"/></Relationships>
            """),
            ("xl/styles.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <styleSheet xmlns="\(main)"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>
            """),
            ("xl/worksheets/sheet1.xml", sheet)
        ]
        return ZipFile.write(parts.map { ZipFile.Entry(name: $0.0, content: Data($0.1.utf8)) })
    }

    // MARK: Adding to a workbook

    /// Adds the books to the end of the workbook's first sheet. Books whose ISBN is already in
    /// the sheet are left out. The sheet's own column order is followed, found from its header row.
    static func append(_ books: [BookMetadata], to file: Data) throws -> AppendResult {
        guard var entries = try? ZipFile.read(file),
              let workbook = entries.first(where: { $0.name == "xl/workbook.xml" }),
              let workbookXML = try? workbook.contents(),
              let relationID = firstSheetRelationID(in: workbookXML),
              let relsEntry = entries.first(where: { $0.name == "xl/_rels/workbook.xml.rels" }),
              let rels = try? relsEntry.contents(),
              let target = relationshipTargets(in: rels)[relationID]
        else { throw Failure.notWorkbook }

        let sheetPath = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + target
        guard let sheetIndex = entries.firstIndex(where: { $0.name == sheetPath }),
              let sheetData = try? entries[sheetIndex].contents(),
              var sheet = String(data: sheetData, encoding: .utf8)
        else { throw Failure.notWorkbook }

        var shared: [String] = []
        if let sharedEntry = entries.first(where: { $0.name == "xl/sharedStrings.xml" }),
           let sharedData = try? sharedEntry.contents() {
            shared = sharedStrings(in: sharedData)
        }
        let scan = SheetScan(shared: shared)
        let parser = XMLParser(data: sheetData)
        parser.delegate = scan
        guard parser.parse() else { throw Failure.notWorkbook }

        // Which sheet column holds which of our fields.
        var columns: [Int]
        var withHeader = false
        if scan.lastRow == 0 {
            columns = Array(headers.indices)
            withHeader = true
        } else {
            let wanted = headers.map { $0.lowercased() }
            columns = wanted.map { name in
                scan.header.first { $0.value.trimmingCharacters(in: .whitespaces).lowercased() == name }?.key ?? -1
            }
            guard columns.contains(where: { $0 >= 0 }), columns[7] >= 0 || columns[0] >= 0 else { throw Failure.noColumns }
        }

        let known = columns[7] >= 0 ? scan.isbns[columns[7]] ?? [] : []
        var fresh: [BookMetadata] = []
        for book in books where !known.contains(normalized(book.isbn)) { fresh.append(book) }
        let skipped = books.count - fresh.count
        guard !fresh.isEmpty || withHeader else { return AppendResult(data: file, added: 0, skipped: skipped) }

        var rows = ""
        var number = scan.lastRow
        if withHeader {
            number += 1
            rows += row(number, columns: columns, values: headers.map { .text($0) }, style: nil)
        }
        for book in fresh {
            number += 1
            let values = cells(for: book)
            let present = columns.indices.filter { columns[$0] >= 0 }
            rows += row(number, columns: present.map { columns[$0] }, values: present.map { values[$0] })
        }

        if let end = sheet.range(of: "</sheetData>") {
            sheet.insert(contentsOf: rows, at: end.lowerBound)
        } else if let empty = sheet.range(of: "<sheetData/>") {
            sheet.replaceSubrange(empty, with: "<sheetData>\(rows)</sheetData>")
        } else {
            throw Failure.notWorkbook
        }
        let lastColumn = max(scan.lastColumn, columns.max() ?? 0)
        if let range = sheet.range(of: "<dimension[^>]*/>", options: .regularExpression) {
            sheet.replaceSubrange(range, with: "<dimension ref=\"A1:\(letters(lastColumn))\(number)\"/>")
        }

        entries[sheetIndex] = ZipFile.Entry(name: sheetPath, content: Data(sheet.utf8), keeping: entries[sheetIndex])
        return AppendResult(data: ZipFile.write(entries), added: fresh.count, skipped: skipped)
    }

    /// An ISBN as digits (and a final X) only, so "978-0-441-17271-9" matches "9780441172719".
    static func normalized(_ text: String) -> String {
        String(text.uppercased().filter { $0.isASCII && ($0.isNumber || $0 == "X") })
    }

    // MARK: Reading the XML parts

    /// The relationship id of the workbook's first sheet.
    private static func firstSheetRelationID(in data: Data) -> String? {
        final class Finder: NSObject, XMLParserDelegate {
            var id: String?
            func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                        qualifiedName: String?, attributes: [String: String]) {
                guard id == nil, name.split(separator: ":").last == "sheet" else { return }
                id = attributes.first { $0.key == "r:id" || $0.key.hasSuffix(":id") }?.value
                if id != nil { parser.abortParsing() }
            }
        }
        let finder = Finder()
        let parser = XMLParser(data: data)
        parser.delegate = finder
        parser.parse()
        return finder.id
    }

    private static func relationshipTargets(in data: Data) -> [String: String] {
        final class Collector: NSObject, XMLParserDelegate {
            var targets: [String: String] = [:]
            func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                        qualifiedName: String?, attributes: [String: String]) {
                if let id = attributes["Id"], let target = attributes["Target"] { targets[id] = target }
            }
        }
        let collector = Collector()
        let parser = XMLParser(data: data)
        parser.delegate = collector
        parser.parse()
        return collector.targets
    }

    /// The shared-strings table: one entry per `<si>`, with rich-text runs joined (phonetic guides left out).
    private static func sharedStrings(in data: Data) -> [String] {
        final class Collector: NSObject, XMLParserDelegate {
            var strings: [String] = []
            var current = ""
            var inText = false
            var phonetic = 0
            func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                        qualifiedName: String?, attributes: [String: String]) {
                switch name.split(separator: ":").last {
                case "si": current = ""
                case "rPh": phonetic += 1
                case "t": inText = true
                default: break
                }
            }
            func parser(_ parser: XMLParser, foundCharacters string: String) {
                if inText, phonetic == 0 { current += string }
            }
            func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
                switch name.split(separator: ":").last {
                case "si": strings.append(current)
                case "rPh": phonetic -= 1
                case "t": inText = false
                default: break
                }
            }
        }
        let collector = Collector()
        let parser = XMLParser(data: data)
        parser.delegate = collector
        parser.parse()
        return collector.strings
    }

    /// Reads a sheet: its first row (the headers), the ISBN-like text in each column, and its extent.
    private final class SheetScan: NSObject, XMLParserDelegate {
        let shared: [String]
        /// Column → header text, from the first row.
        var header: [Int: String] = [:]
        /// Column → every cell's text, as digits, for spotting ISBNs already there.
        var isbns: [Int: Set<String>] = [:]
        var lastRow = 0
        var lastColumn = 0

        private var rowNumber = 0
        private var firstRow: Int?
        private var reference = ""
        private var type = ""
        private var value = ""
        private var inline = ""
        private var inValue = false
        private var inInline = false
        private var inCell = false

        init(shared: [String]) { self.shared = shared }

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            switch name.split(separator: ":").last {
            case "row":
                rowNumber = Int(attributes["r"] ?? "") ?? rowNumber + 1
                lastRow = max(lastRow, rowNumber)
                if firstRow == nil { firstRow = rowNumber }
            case "c":
                inCell = true
                reference = attributes["r"] ?? ""
                type = attributes["t"] ?? ""
                value = ""
                inline = ""
            case "v": inValue = inCell
            case "t": inInline = inCell
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if inValue { value += string } else if inInline { inline += string }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            switch name.split(separator: ":").last {
            case "v": inValue = false
            case "t": inInline = false
            case "c":
                inCell = false
                let text: String
                switch type {
                case "s": text = Int(value.trimmingCharacters(in: .whitespaces)).flatMap { shared.indices.contains($0) ? shared[$0] : nil } ?? ""
                case "inlineStr": text = inline
                default: text = value
                }
                let col = XLSX.column(of: reference)
                lastColumn = max(lastColumn, col)
                if rowNumber == firstRow { header[col] = text }
                else if !text.isEmpty { isbns[col, default: []].insert(XLSX.normalized(text)) }
            default: break
            }
        }
    }
}

// MARK: - Zip

/// Just enough of the zip format for .xlsx files: no encryption, no zip64.
enum ZipFile {
    struct Entry {
        var name: String
        var flags: UInt16 = 0x0800
        var method: UInt16
        var time: UInt16
        var date: UInt16
        var crc: UInt32
        var uncompressedSize: UInt32
        /// The stored bytes, compressed if `method` is 8.
        var stored: Data

        /// A new entry, compressed if that makes it smaller.
        init(name: String, content: Data) {
            self.name = name
            crc = CRC32.checksum(content)
            uncompressedSize = UInt32(content.count)
            let (time, date) = Self.dosNow()
            self.time = time
            self.date = date
            if let packed = Self.deflate(content), packed.count < content.count {
                method = 8
                stored = packed
            } else {
                method = 0
                stored = content
            }
        }

        /// New contents for an existing entry, keeping its date.
        init(name: String, content: Data, keeping old: Entry) {
            self.init(name: name, content: content)
            time = old.time
            date = old.date
        }

        init(name: String, flags: UInt16, method: UInt16, time: UInt16, date: UInt16,
             crc: UInt32, uncompressedSize: UInt32, stored: Data) {
            self.name = name
            self.flags = flags & ~0x0008     // sizes are written up front
            self.method = method
            self.time = time
            self.date = date
            self.crc = crc
            self.uncompressedSize = uncompressedSize
            self.stored = stored
        }

        func contents() throws -> Data {
            if method == 0 { return stored }
            guard method == 8 else { throw XLSX.Failure.notWorkbook }
            guard uncompressedSize > 0 else { return Data() }
            // A damaged or hostile file can claim any size; no real sheet is this big.
            guard uncompressedSize < 300_000_000 else { throw XLSX.Failure.notWorkbook }
            var output = Data(count: Int(uncompressedSize))
            let written = output.withUnsafeMutableBytes { out in
                stored.withUnsafeBytes { input in
                    compression_decode_buffer(
                        out.bindMemory(to: UInt8.self).baseAddress!, Int(uncompressedSize),
                        input.bindMemory(to: UInt8.self).baseAddress!, stored.count, nil, COMPRESSION_ZLIB
                    )
                }
            }
            guard written == Int(uncompressedSize) else { throw XLSX.Failure.notWorkbook }
            return output
        }

        private static func deflate(_ data: Data) -> Data? {
            guard !data.isEmpty else { return nil }
            var output = Data(count: data.count + 64)
            let capacity = output.count
            let written = output.withUnsafeMutableBytes { out in
                data.withUnsafeBytes { input in
                    compression_encode_buffer(
                        out.bindMemory(to: UInt8.self).baseAddress!, capacity,
                        input.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB
                    )
                }
            }
            guard written > 0 else { return nil }
            return output.prefix(written)
        }

        private static func dosNow() -> (UInt16, UInt16) {
            let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: .now)
            let year = max((parts.year ?? 1980) - 1980, 0)
            let time = UInt16((parts.hour ?? 0) << 11 | (parts.minute ?? 0) << 5 | (parts.second ?? 0) / 2)
            let date = UInt16(year << 9 | (parts.month ?? 1) << 5 | (parts.day ?? 1))
            return (time, date)
        }
    }

    static func read(_ data: Data) throws -> [Entry] {
        let bytes = [UInt8](data)
        func u16(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
        func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }

        // The end-of-central-directory record is within the last 64 KB.
        guard bytes.count >= 22 else { throw XLSX.Failure.notWorkbook }
        var end = bytes.count - 22
        while end >= max(0, bytes.count - 65557), u32(end) != 0x06054b50 { end -= 1 }
        guard end >= 0, u32(end) == 0x06054b50 else { throw XLSX.Failure.notWorkbook }
        let count = u16(end + 10)
        var at = u32(end + 16)
        guard count != 0xFFFF, at != 0xFFFFFFFF else { throw XLSX.Failure.notWorkbook }   // zip64

        var entries: [Entry] = []
        for _ in 0..<count {
            guard at + 46 <= bytes.count, u32(at) == 0x02014b50 else { throw XLSX.Failure.notWorkbook }
            let flags = UInt16(u16(at + 8))
            let method = UInt16(u16(at + 10))
            let compressed = u32(at + 20)
            let nameLength = u16(at + 28), extraLength = u16(at + 30), commentLength = u16(at + 32)
            let localOffset = u32(at + 42)
            guard flags & 1 == 0, at + 46 + nameLength <= bytes.count,
                  let name = String(bytes: bytes[(at + 46)..<(at + 46 + nameLength)], encoding: .utf8),
                  localOffset + 30 <= bytes.count, u32(localOffset) == 0x04034b50 else { throw XLSX.Failure.notWorkbook }
            let start = localOffset + 30 + u16(localOffset + 26) + u16(localOffset + 28)
            guard start + compressed <= bytes.count else { throw XLSX.Failure.notWorkbook }
            entries.append(Entry(
                name: name, flags: flags, method: method,
                time: UInt16(u16(at + 12)), date: UInt16(u16(at + 14)),
                crc: UInt32(u32(at + 16)), uncompressedSize: UInt32(u32(at + 24)),
                stored: Data(bytes[start..<(start + compressed)])
            ))
            at += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    static func write(_ entries: [Entry]) -> Data {
        var out = Data()
        var directory = Data()
        func put16(_ value: Int, to data: inout Data) { data.append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)]) }
        func put32(_ value: Int, to data: inout Data) { put16(value & 0xFFFF, to: &data); put16(value >> 16 & 0xFFFF, to: &data) }

        for entry in entries {
            let name = Data(entry.name.utf8)
            let offset = out.count
            put32(0x04034b50, to: &out); put16(20, to: &out); put16(Int(entry.flags), to: &out); put16(Int(entry.method), to: &out)
            put16(Int(entry.time), to: &out); put16(Int(entry.date), to: &out); put32(Int(entry.crc), to: &out)
            put32(entry.stored.count, to: &out); put32(Int(entry.uncompressedSize), to: &out)
            put16(name.count, to: &out); put16(0, to: &out)
            out.append(name); out.append(entry.stored)

            put32(0x02014b50, to: &directory); put16(20, to: &directory); put16(20, to: &directory)
            put16(Int(entry.flags), to: &directory); put16(Int(entry.method), to: &directory)
            put16(Int(entry.time), to: &directory); put16(Int(entry.date), to: &directory); put32(Int(entry.crc), to: &directory)
            put32(entry.stored.count, to: &directory); put32(Int(entry.uncompressedSize), to: &directory)
            put16(name.count, to: &directory); put16(0, to: &directory); put16(0, to: &directory)
            put16(0, to: &directory); put16(0, to: &directory); put32(0, to: &directory); put32(offset, to: &directory)
            directory.append(name)
        }
        let directoryStart = out.count
        out.append(directory)
        put32(0x06054b50, to: &out); put16(0, to: &out); put16(0, to: &out)
        put16(entries.count, to: &out); put16(entries.count, to: &out)
        put32(directory.count, to: &out); put32(directoryStart, to: &out); put16(0, to: &out)
        return out
    }
}

enum CRC32Check { static func checksum(_ data: Data) -> UInt32 { CRC32.checksum(data) } }

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { index in
        (0..<8).reduce(UInt32(index)) { value, _ in value & 1 == 1 ? 0xEDB88320 ^ (value >> 1) : value >> 1 }
    }

    static func checksum(_ data: Data) -> UInt32 {
        ~data.reduce(~UInt32(0)) { crc, byte in table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
    }
}
