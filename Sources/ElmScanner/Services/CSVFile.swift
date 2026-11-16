import Foundation

/// Writes books as CSV, or adds them to the end of a CSV file made earlier.
enum CSVFile {
    enum Failure: LocalizedError {
        /// Not UTF-8 text (a file saved in an older encoding, or not text at all).
        case notText
        /// The file has data but not ElmScanner's columns.
        case noColumns

        var errorDescription: String? {
            switch self {
            case .notText:
                return String(localized: "That file can't be read as UTF-8 text, so ElmScanner can't add to it.")
            case .noColumns:
                return String(localized: "The file doesn't have ElmScanner's columns (Title, Authors, ISBN…). Choose a file exported from ElmScanner, or an empty file.")
            }
        }
    }

    /// Excel needs this at the start of a UTF-8 file to show Japanese and accented text correctly.
    private static let byteOrderMark = "\u{FEFF}"

    // MARK: Writing

    static func create(_ books: [BookMetadata]) -> Data {
        var lines = [line(XLSX.headers, delimiter: ",", columns: Array(XLSX.headers.indices), width: XLSX.headers.count)]
        for book in books {
            lines.append(line(XLSX.values(for: book), delimiter: ",", columns: Array(XLSX.headers.indices), width: XLSX.headers.count, guardFormulas: true))
        }
        return Data((byteOrderMark + lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    /// One record: `values[i]` goes in `columns[i]`, with empty fields in between and up to `width` columns.
    private static func line(_ values: [String], delimiter: Character, columns: [Int], width: Int, guardFormulas: Bool = false) -> String {
        var fields = Array(repeating: "", count: width)
        for (value, column) in zip(values, columns) where column >= 0 && column < width { fields[column] = value }
        return fields.map { quoted($0, delimiter: delimiter, guardFormulas: guardFormulas) }.joined(separator: String(delimiter))
    }

    /// A field in CSV form. A text that starts like a formula gets a leading apostrophe, so
    /// a spreadsheet shows it as text instead of running it.
    private static func quoted(_ field: String, delimiter: Character, guardFormulas: Bool) -> String {
        var text = field
        if guardFormulas, let first = text.first, "=+-@\t\r".contains(first) { text = "'" + text }
        guard text.contains(where: { $0 == delimiter || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: Adding to a file

    /// Adds the books to the end of the file, following its own column order (found from its
    /// header row). Books whose ISBN is already there are left out. What was in the file is
    /// kept byte for byte; only the new lines are added.
    static func append(_ books: [BookMetadata], to file: Data) throws -> AppendResult {
        guard let original = String(data: file, encoding: .utf8) else { throw Failure.notText }
        let text = original.hasPrefix(byteOrderMark) ? String(original.dropFirst()) : original
        let end = text.contains("\r\n") ? "\r\n" : "\n"

        var columns = Array(XLSX.headers.indices)
        var width = XLSX.headers.count
        var delimiter: Character = ","
        var known = Set<String>()
        var needsHeader = true
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            needsHeader = false
            delimiter = Self.delimiter(of: text)
            let records = parse(text, delimiter: delimiter)
            let header = (records.first ?? []).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            columns = XLSX.headers.map { name in header.firstIndex(of: name.lowercased()) ?? -1 }
            guard columns.contains(where: { $0 >= 0 }) else { throw Failure.noColumns }
            width = header.count
            if columns[7] >= 0 {
                for record in records.dropFirst() where columns[7] < record.count { known.insert(XLSX.normalized(record[columns[7]])) }
            }
        }

        let fresh = books.filter { !known.contains(XLSX.normalized($0.isbn)) }
        let skipped = books.count - fresh.count
        guard !fresh.isEmpty else { return AppendResult(data: file, added: 0, skipped: skipped) }

        var lines: [String] = []
        if needsHeader { lines.append(line(XLSX.headers, delimiter: delimiter, columns: columns, width: width)) }
        for book in fresh {
            lines.append(line(XLSX.values(for: book), delimiter: delimiter, columns: columns, width: width, guardFormulas: true))
        }
        var added = Data()
        if text.isEmpty && !original.hasPrefix(byteOrderMark) { added.append(Data(byteOrderMark.utf8)) }
        // The last line of the file may have no line break after it.
        if !text.isEmpty, !text.hasSuffix("\n"), !text.hasSuffix("\r") { added.append(Data(end.utf8)) }
        added.append(Data((lines.joined(separator: end) + end).utf8))
        return AppendResult(data: file + added, added: fresh.count, skipped: skipped)
    }

    /// Comma, semicolon or tab: whichever the first line uses most (outside quotes).
    private static func delimiter(of text: String) -> Character {
        var counts: [Character: Int] = [",": 0, ";": 0, "\t": 0]
        var quoted = false
        for character in text {
            if character == "\"" { quoted.toggle() }
            if !quoted, character == "\n" || character == "\r" { break }
            if !quoted, counts[character] != nil { counts[character, default: 0] += 1 }
        }
        let best = counts.max { $0.value < $1.value }
        return (best?.value ?? 0) > 0 ? best!.key : ","
    }

    /// The records of a CSV text (RFC 4180: quoted fields may hold the delimiter, quotes and line breaks).
    static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var characters = Array(text)[...]
        while let character = characters.popFirst() {
            if inQuotes {
                if character == "\"" {
                    if characters.first == "\"" { field.append("\""); characters.removeFirst() } else { inQuotes = false }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == delimiter {
                record.append(field)
                field = ""
            } else if character == "\n" || character == "\r\n" || character == "\r" {
                record.append(field)
                field = ""
                if record != [""] { records.append(record) }
                record = []
            } else {
                field.append(character)
            }
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            records.append(record)
        }
        return records
    }
}
