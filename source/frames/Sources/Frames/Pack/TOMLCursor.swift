//
//  TOMLCursor.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct TOMLCursor {
    // MARK: - Property
    let bytes: [UInt8]
    let file: String
    var offset = 0

    var isAtEnd: Bool {
        offset >= bytes.count
    }

    // MARK: - Initializer
    init(
        bytes: [UInt8],
        file: String
    ) {
        self.bytes = bytes
        self.file = file
    }

    // MARK: - Public
    func peek(_ ahead: Int = 0) -> UInt8? {
        offset + ahead < bytes.count ? bytes[offset + ahead] : nil
    }

    func peek(_ word: String) -> Bool {
        let wordBytes = Array(word.utf8)
        guard offset + wordBytes.count <= bytes.count else { return false }

        return Array(bytes[offset..<offset + wordBytes.count]) == wordBytes
    }

    mutating func advance(_ count: Int = 1) {
        offset += count
    }

    // Spaces and tabs only, since a line ends a key/value pair.
    mutating func skipSpaces() {
        while let byte = peek(), byte == 0x20 || byte == 0x09 {
            advance()
        }
    }

    mutating func skipComment() {
        guard peek() == UInt8(ascii: "#") else { return }

        while let byte = peek(), byte != 0x0A {
            advance()
        }
    }

    // Blank lines, comments and the ends of lines between the parts of an array.
    mutating func skipBlank() {
        while true {
            skipSpaces()
            skipComment()
            guard let byte = peek(), byte == 0x0A || byte == 0x0D else { return }

            advance()
        }
    }

    mutating func expect(_ byte: UInt8, _ reason: String) throws {
        guard peek() == byte else { throw error(reason) }

        advance()
    }

    // A pair or header is followed only by a comment before the end of its line.
    mutating func expectEndOfLine() throws {
        skipSpaces()
        skipComment()
        if peek() == 0x0D, peek(1) == 0x0A {
            advance()
        }
        guard isAtEnd || peek() == 0x0A else { throw error("expected the end of the line") }

        advance()
    }

    func error(_ reason: String) -> PackError {
        let consumed = bytes[..<min(offset, bytes.count)]
        let line = consumed.filter { $0 == 0x0A }.count + 1
        let lineStart = consumed.lastIndex(of: 0x0A).map { $0 + 1 } ?? 0
        // A UTF-8 continuation byte belongs to the character it continues, so only the other bytes start a column.
        let column = consumed[lineStart...].filter { !(0x80..<0xC0).contains($0) }.count + 1
        return .manifestSyntax(file: file, line: line, column: column, reason: reason)
    }

    // MARK: - Private
}
