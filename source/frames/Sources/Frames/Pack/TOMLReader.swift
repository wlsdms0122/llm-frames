//
//  TOMLReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Reads a TOML file into the same tree a JSON file reads into: tables are objects, and integers and floats are
// numbers. Dates and times are not read, since a manifest holds none that frames reads.
struct TOMLReader: Sendable {
    // MARK: - Property
    private let file: String

    // MARK: - Initializer
    init(file: String) {
        self.file = file
    }

    // MARK: - Public
    func read(_ data: Data) throws -> JSONValue {
        var cursor = TOMLCursor(bytes: Array(data), file: file)
        var root = JSONObject()
        var table: [String] = []
        var headers: Set<[String]> = []

        while true {
            cursor.skipBlank()
            guard let byte = cursor.peek() else { break }

            if byte == UInt8(ascii: "["), cursor.peek(1) == UInt8(ascii: "[") {
                cursor.advance(2)
                table = try readKeys(&cursor)
                try cursor.expect(UInt8(ascii: "]"), "expected \"]]\" after a table name")
                try cursor.expect(UInt8(ascii: "]"), "expected \"]]\" after a table name")
                // Each element of an array of tables starts again, so its tables may be written again.
                headers = headers.filter { !$0.starts(with: table) }
                root = try updating(root, at: table[...], cursor: cursor) { existing in
                    switch existing {
                    case nil:
                        return .array([.object(JSONObject())])

                    case let .array(elements):
                        return .array(elements + [.object(JSONObject())])

                    default:
                        throw cursor.error("\(table.joined(separator: ".")) already holds a value")
                    }
                }
            } else if byte == UInt8(ascii: "[") {
                cursor.advance()
                table = try readKeys(&cursor)
                try cursor.expect(UInt8(ascii: "]"), "expected \"]\" after a table name")
                guard headers.insert(table).inserted else {
                    throw cursor.error("table \(table.joined(separator: ".")) is written twice")
                }

                root = try updating(root, at: table[...], cursor: cursor) { existing in
                    switch existing {
                    case nil:
                        return .object(JSONObject())

                    case let .object(object):
                        return .object(object)

                    default:
                        throw cursor.error("\(table.joined(separator: ".")) already holds a value")
                    }
                }
            } else {
                let (keys, value) = try readPair(&cursor)
                root = try inserting(value, at: table + keys, into: root, cursor: cursor)
            }

            try cursor.expectEndOfLine()
        }

        return .object(root)
    }

    // MARK: - Private
    private func readPair(_ cursor: inout TOMLCursor) throws -> ([String], JSONValue) {
        let keys = try readKeys(&cursor)
        try cursor.expect(UInt8(ascii: "="), "expected \"=\" after a key")
        cursor.skipSpaces()

        return (keys, try readValue(&cursor))
    }

    private func readKeys(_ cursor: inout TOMLCursor) throws -> [String] {
        var keys: [String] = []
        repeat {
            if !keys.isEmpty {
                cursor.advance()
            }
            cursor.skipSpaces()
            keys.append(try readKey(&cursor))
            cursor.skipSpaces()
        } while cursor.peek() == UInt8(ascii: ".")

        return keys
    }

    private func readKey(_ cursor: inout TOMLCursor) throws -> String {
        switch cursor.peek() {
        case UInt8(ascii: "\""):
            cursor.advance()
            return try readBasicString(&cursor, isMultiline: false)

        case UInt8(ascii: "'"):
            cursor.advance()
            return try readLiteralString(&cursor, isMultiline: false)

        default:
            var bytes: [UInt8] = []
            while let byte = cursor.peek(), isBareKeyByte(byte) {
                bytes.append(byte)
                cursor.advance()
            }
            guard !bytes.isEmpty else { throw cursor.error("expected a key") }

            return String(decoding: bytes, as: UTF8.self)
        }
    }

    private func readValue(_ cursor: inout TOMLCursor) throws -> JSONValue {
        if cursor.peek("\"\"\"") {
            cursor.advance(3)
            return .string(try readBasicString(&cursor, isMultiline: true))
        }
        if cursor.peek("'''") {
            cursor.advance(3)
            return .string(try readLiteralString(&cursor, isMultiline: true))
        }

        switch cursor.peek() {
        case UInt8(ascii: "\""):
            cursor.advance()
            return .string(try readBasicString(&cursor, isMultiline: false))

        case UInt8(ascii: "'"):
            cursor.advance()
            return .string(try readLiteralString(&cursor, isMultiline: false))

        case UInt8(ascii: "["):
            cursor.advance()
            return try readArray(&cursor)

        case UInt8(ascii: "{"):
            cursor.advance()
            return try readInlineTable(&cursor)

        case nil:
            throw cursor.error("expected a value")

        default:
            return try readWord(&cursor)
        }
    }

    private func readArray(_ cursor: inout TOMLCursor) throws -> JSONValue {
        var elements: [JSONValue] = []
        while true {
            cursor.skipBlank()
            if cursor.peek() == UInt8(ascii: "]") {
                cursor.advance()
                return .array(elements)
            }

            elements.append(try readValue(&cursor))
            cursor.skipBlank()
            guard cursor.peek() != UInt8(ascii: ",") else {
                cursor.advance()
                continue
            }

            try cursor.expect(UInt8(ascii: "]"), "expected \",\" or \"]\" in an array")
            return .array(elements)
        }
    }

    private func readInlineTable(_ cursor: inout TOMLCursor) throws -> JSONValue {
        var object = JSONObject()
        cursor.skipSpaces()
        if cursor.peek() == UInt8(ascii: "}") {
            cursor.advance()
            return .object(object)
        }

        while true {
            let (keys, value) = try readPair(&cursor)
            object = try inserting(value, at: keys, into: object, cursor: cursor)
            cursor.skipSpaces()
            guard cursor.peek() != UInt8(ascii: ",") else {
                cursor.advance()
                cursor.skipSpaces()
                continue
            }

            try cursor.expect(UInt8(ascii: "}"), "expected \",\" or \"}\" in an inline table")
            return .object(object)
        }
    }

    private func readWord(_ cursor: inout TOMLCursor) throws -> JSONValue {
        var bytes: [UInt8] = []
        while let byte = cursor.peek(), isBareKeyByte(byte) || [UInt8(ascii: "+"), UInt8(ascii: "."), UInt8(ascii: ":")].contains(byte) {
            bytes.append(byte)
            cursor.advance()
        }

        let word = String(decoding: bytes, as: UTF8.self)
        switch word {
        case "true":
            return .bool(true)

        case "false":
            return .bool(false)

        default:
            return .number(try number(word, cursor: cursor))
        }
    }

    private func number(
        _ word: String,
        cursor: TOMLCursor
    ) throws -> Double {
        let digits = word.replacingOccurrences(of: "_", with: "")
        let radixes: [(prefix: String, radix: Int)] = [("0x", 16), ("0o", 8), ("0b", 2)]
        if let (prefix, radix) = radixes.first(where: { digits.hasPrefix($0.prefix) }) {
            guard let integer = Int(digits.dropFirst(prefix.count), radix: radix) else {
                throw cursor.error("\"\(word)\" is not a number")
            }

            return Double(integer)
        }
        guard !digits.contains(":"), !digits.dropFirst().contains("-") || digits.lowercased().contains("e") else {
            throw cursor.error("\"\(word)\" is a date or time, which a manifest does not hold")
        }
        guard !digits.isEmpty, let number = Double(digits) else {
            throw cursor.error(word.isEmpty ? "expected a value" : "\"\(word)\" is not a value")
        }

        return number
    }

    private func readBasicString(
        _ cursor: inout TOMLCursor,
        isMultiline: Bool
    ) throws -> String {
        var bytes: [UInt8] = []
        if isMultiline {
            skipFirstNewline(&cursor)
        }

        while true {
            if isMultiline, cursor.peek("\"\"\""), cursor.peek(3) != UInt8(ascii: "\"") {
                cursor.advance(3)
                return String(decoding: bytes, as: UTF8.self)
            }
            guard let byte = cursor.peek() else { throw cursor.error("a string is not closed") }

            switch byte {
            case UInt8(ascii: "\"") where !isMultiline:
                cursor.advance()
                return String(decoding: bytes, as: UTF8.self)

            case 0x0A where !isMultiline:
                throw cursor.error("a string is not closed before the end of the line")

            case UInt8(ascii: "\\"):
                cursor.advance()
                bytes += try readEscape(&cursor, isMultiline: isMultiline)

            default:
                bytes.append(byte)
                cursor.advance()
            }
        }
    }

    private func readLiteralString(
        _ cursor: inout TOMLCursor,
        isMultiline: Bool
    ) throws -> String {
        var bytes: [UInt8] = []
        if isMultiline {
            skipFirstNewline(&cursor)
        }

        while true {
            if isMultiline, cursor.peek("'''"), cursor.peek(3) != UInt8(ascii: "'") {
                cursor.advance(3)
                return String(decoding: bytes, as: UTF8.self)
            }
            guard let byte = cursor.peek() else { throw cursor.error("a string is not closed") }
            guard isMultiline || byte != 0x0A else {
                throw cursor.error("a string is not closed before the end of the line")
            }

            cursor.advance()
            guard isMultiline || byte != UInt8(ascii: "'") else { return String(decoding: bytes, as: UTF8.self) }

            bytes.append(byte)
        }
    }

    private func readEscape(
        _ cursor: inout TOMLCursor,
        isMultiline: Bool
    ) throws -> [UInt8] {
        guard let byte = cursor.peek() else { throw cursor.error("a string is not closed") }

        let simple: [UInt8: UInt8] = [
            UInt8(ascii: "b"): 0x08, UInt8(ascii: "t"): 0x09, UInt8(ascii: "n"): 0x0A, UInt8(ascii: "f"): 0x0C,
            UInt8(ascii: "r"): 0x0D, UInt8(ascii: "\""): 0x22, UInt8(ascii: "\\"): 0x5C
        ]
        if let escaped = simple[byte] {
            cursor.advance()
            return [escaped]
        }
        if byte == UInt8(ascii: "u") || byte == UInt8(ascii: "U") {
            cursor.advance()
            return try readUnicodeEscape(&cursor, length: byte == UInt8(ascii: "u") ? 4 : 8)
        }
        // A backslash that ends a line in a multi-line string trims the line break and the whitespace after it.
        if isMultiline, [0x20, 0x09, 0x0A, 0x0D].contains(byte) {
            while let next = cursor.peek(), [0x20, 0x09, 0x0A, 0x0D].contains(next) {
                cursor.advance()
            }

            return []
        }

        throw cursor.error("unknown escape")
    }

    private func readUnicodeEscape(
        _ cursor: inout TOMLCursor,
        length: Int
    ) throws -> [UInt8] {
        var hex = ""
        for _ in 0..<length {
            guard let byte = cursor.peek() else { throw cursor.error("a string is not closed") }

            hex.append(Character(UnicodeScalar(byte)))
            cursor.advance()
        }
        guard let code = UInt32(hex, radix: 16), let scalar = UnicodeScalar(code) else {
            throw cursor.error("\\u\(hex) is not a Unicode scalar")
        }

        return Array(String(scalar).utf8)
    }

    private func skipFirstNewline(_ cursor: inout TOMLCursor) {
        if cursor.peek() == 0x0D, cursor.peek(1) == 0x0A {
            cursor.advance(2)
        } else if cursor.peek() == 0x0A {
            cursor.advance()
        }
    }

    private func inserting(
        _ value: JSONValue,
        at path: [String],
        into object: JSONObject,
        cursor: TOMLCursor
    ) throws -> JSONObject {
        try updating(object, at: path[...], cursor: cursor) { existing in
            guard existing == nil else { throw cursor.error("key \(path.joined(separator: ".")) is written twice") }

            return value
        }
    }

    // Walks the path through tables, and into the last table of an array of tables, as TOML resolves a name.
    private func updating(
        _ object: JSONObject,
        at path: ArraySlice<String>,
        cursor: TOMLCursor,
        leaf: (JSONValue?) throws -> JSONValue
    ) throws -> JSONObject {
        guard let key = path.first else { return object }
        guard path.count > 1 else { return object.setting(key, to: try leaf(object[key])) }

        switch object[key] {
        case nil:
            return object.setting(key, to: .object(try updating(JSONObject(), at: path.dropFirst(), cursor: cursor, leaf: leaf)))

        case let .object(child):
            return object.setting(key, to: .object(try updating(child, at: path.dropFirst(), cursor: cursor, leaf: leaf)))

        case let .array(elements):
            guard let last = elements.last?.objectValue else { throw cursor.error("\(key) already holds a value") }

            let updated = try updating(last, at: path.dropFirst(), cursor: cursor, leaf: leaf)
            return object.setting(key, to: .array(elements.dropLast() + [.object(updated)]))

        default:
            throw cursor.error("\(key) already holds a value")
        }
    }

    private func isBareKeyByte(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
            || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
            || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
            || byte == UInt8(ascii: "_")
            || byte == UInt8(ascii: "-")
    }
}
