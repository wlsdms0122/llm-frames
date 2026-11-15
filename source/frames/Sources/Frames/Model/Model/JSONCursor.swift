//
//  JSONCursor.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct JSONCursor {
    // MARK: - Property
    let bytes: [UInt8]
    var offset = 0

    var isAtEnd: Bool {
        offset >= bytes.count
    }

    // MARK: - Initializer
    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    // MARK: - Public
    func peek() -> UInt8? {
        isAtEnd ? nil : bytes[offset]
    }

    mutating func advance() {
        offset += 1
    }

    mutating func skipWhitespace() {
        while let byte = peek(), [0x20, 0x09, 0x0A, 0x0D].contains(byte) {
            advance()
        }
    }

    mutating func skipDigits() -> Int {
        var count = 0
        while let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) {
            advance()
            count += 1
        }

        return count
    }

    mutating func expect(_ word: String) throws {
        for byte in word.utf8 {
            guard peek() == byte else {
                throw error("unexpected character")
            }

            advance()
        }
    }

    func error(_ reason: String) -> ModelError {
        let consumed = bytes[..<min(offset, bytes.count)]
        let line = consumed.filter { $0 == 0x0A }.count + 1
        let lineStart = consumed.lastIndex(of: 0x0A).map { $0 + 1 } ?? 0
        let column = offset - lineStart + 1
        return .syntax(line: line, column: column, reason: reason)
    }

    // MARK: - Private
}
