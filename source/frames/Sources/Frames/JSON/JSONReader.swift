//
//  JSONReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

package struct JSONReader: Sendable {
    // MARK: - Property
    // The file other than the document that is read, as it was referred to, so its errors name it.
    private let file: String?

    // MARK: - Initializer
    package init(file: String? = nil) {
        self.file = file
    }

    // MARK: - Public
    package func read(_ data: Data) throws -> JSONValue {
        var cursor = JSONCursor(bytes: Array(data), file: file)
        cursor.skipWhitespace()
        let value = try readValue(&cursor)
        cursor.skipWhitespace()
        guard cursor.isAtEnd else {
            throw cursor.error("unexpected content after the value")
        }

        return value
    }

    func read(_ text: String) throws -> JSONValue {
        try read(Data(text.utf8))
    }

    // MARK: - Private
    private func readValue(_ cursor: inout JSONCursor) throws -> JSONValue {
        guard let byte = cursor.peek() else {
            throw cursor.error("unexpected end of input")
        }

        switch byte {
        case UInt8(ascii: "{"):
            return try readObject(&cursor)

        case UInt8(ascii: "["):
            return try readArray(&cursor)

        case UInt8(ascii: "\""):
            return .string(try readString(&cursor))

        case UInt8(ascii: "t"):
            try cursor.expect("true")
            return .bool(true)

        case UInt8(ascii: "f"):
            try cursor.expect("false")
            return .bool(false)

        case UInt8(ascii: "n"):
            try cursor.expect("null")
            return .null

        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
            return .number(try readNumber(&cursor))

        default:
            throw cursor.error("unexpected character")
        }
    }

    private func readObject(_ cursor: inout JSONCursor) throws -> JSONValue {
        cursor.advance()
        var members: [JSONMember] = []
        cursor.skipWhitespace()
        if cursor.peek() == UInt8(ascii: "}") {
            cursor.advance()
            return .object(JSONObject(members: members))
        }

        while true {
            cursor.skipWhitespace()
            guard cursor.peek() == UInt8(ascii: "\"") else {
                throw cursor.error("expected a key in quotes")
            }

            let keyCursor = cursor
            let key = try readString(&cursor)
            // A second value for a key would silently win over the first.
            guard !members.contains(where: { $0.key == key }) else {
                throw keyCursor.error("key \"\(key)\" is written twice")
            }

            cursor.skipWhitespace()
            guard cursor.peek() == UInt8(ascii: ":") else {
                throw cursor.error("expected \":\" after a key")
            }

            cursor.advance()
            cursor.skipWhitespace()
            members.append(JSONMember(key: key, value: try readValue(&cursor)))
            cursor.skipWhitespace()

            switch cursor.peek() {
            case UInt8(ascii: ","):
                cursor.advance()

            case UInt8(ascii: "}"):
                cursor.advance()
                return .object(JSONObject(members: members))

            default:
                throw cursor.error("expected \",\" or \"}\" in an object")
            }
        }
    }

    private func readArray(_ cursor: inout JSONCursor) throws -> JSONValue {
        cursor.advance()
        var elements: [JSONValue] = []
        cursor.skipWhitespace()
        if cursor.peek() == UInt8(ascii: "]") {
            cursor.advance()
            return .array(elements)
        }

        while true {
            cursor.skipWhitespace()
            elements.append(try readValue(&cursor))
            cursor.skipWhitespace()

            switch cursor.peek() {
            case UInt8(ascii: ","):
                cursor.advance()

            case UInt8(ascii: "]"):
                cursor.advance()
                return .array(elements)

            default:
                throw cursor.error("expected \",\" or \"]\" in a list")
            }
        }
    }

    private func readString(_ cursor: inout JSONCursor) throws -> String {
        cursor.advance()
        var bytes: [UInt8] = []

        while true {
            guard let byte = cursor.peek() else {
                throw cursor.error("a string is not closed")
            }

            cursor.advance()
            switch byte {
            case UInt8(ascii: "\""):
                guard let string = String(bytes: bytes, encoding: .utf8) else {
                    throw cursor.error("a string is not valid UTF-8")
                }

                return string

            case UInt8(ascii: "\\"):
                bytes.append(contentsOf: try readEscape(&cursor))

            case 0x00..<0x20:
                throw cursor.error("a control character must be escaped in a string")

            default:
                bytes.append(byte)
            }
        }
    }

    private func readEscape(_ cursor: inout JSONCursor) throws -> [UInt8] {
        guard let byte = cursor.peek() else {
            throw cursor.error("an escape is not finished")
        }

        cursor.advance()
        switch byte {
        case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"):
            return [byte]

        case UInt8(ascii: "b"):
            return [0x08]

        case UInt8(ascii: "f"):
            return [0x0C]

        case UInt8(ascii: "n"):
            return [0x0A]

        case UInt8(ascii: "r"):
            return [0x0D]

        case UInt8(ascii: "t"):
            return [0x09]

        case UInt8(ascii: "u"):
            return try readUnicodeEscape(&cursor)

        default:
            throw cursor.error("unknown escape")
        }
    }

    private func readUnicodeEscape(_ cursor: inout JSONCursor) throws -> [UInt8] {
        let first = try readHexQuad(&cursor)
        var scalarValue = first

        if (0xD800..<0xDC00).contains(first) {
            guard cursor.peek() == UInt8(ascii: "\\") else {
                throw cursor.error("a high surrogate is not followed by a low one")
            }

            cursor.advance()
            guard cursor.peek() == UInt8(ascii: "u") else {
                throw cursor.error("a high surrogate is not followed by a low one")
            }

            cursor.advance()
            let second = try readHexQuad(&cursor)
            guard (0xDC00..<0xE000).contains(second) else {
                throw cursor.error("a high surrogate is not followed by a low one")
            }

            scalarValue = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
        }

        guard let scalar = Unicode.Scalar(scalarValue) else {
            throw cursor.error("an escape names no character")
        }

        return Array(String(Character(scalar)).utf8)
    }

    private func readHexQuad(_ cursor: inout JSONCursor) throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0..<4 {
            guard let byte = cursor.peek(), let digit = hexDigit(byte) else {
                throw cursor.error("expected four hexadecimal digits")
            }

            cursor.advance()
            value = value * 16 + digit
        }

        return value
    }

    private func hexDigit(_ byte: UInt8) -> UInt32? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            UInt32(byte - UInt8(ascii: "0"))

        case UInt8(ascii: "a")...UInt8(ascii: "f"):
            UInt32(byte - UInt8(ascii: "a") + 10)

        case UInt8(ascii: "A")...UInt8(ascii: "F"):
            UInt32(byte - UInt8(ascii: "A") + 10)

        default:
            nil
        }
    }

    private func readNumber(_ cursor: inout JSONCursor) throws -> Double {
        let start = cursor.offset
        if cursor.peek() == UInt8(ascii: "-") {
            cursor.advance()
        }

        if cursor.peek() == UInt8(ascii: "0") {
            cursor.advance()
        } else {
            guard cursor.skipDigits() > 0 else {
                throw cursor.error("expected a digit")
            }
        }

        if cursor.peek() == UInt8(ascii: ".") {
            cursor.advance()
            guard cursor.skipDigits() > 0 else {
                throw cursor.error("expected a digit after the decimal point")
            }
        }

        if cursor.peek() == UInt8(ascii: "e") || cursor.peek() == UInt8(ascii: "E") {
            cursor.advance()
            if cursor.peek() == UInt8(ascii: "+") || cursor.peek() == UInt8(ascii: "-") {
                cursor.advance()
            }

            guard cursor.skipDigits() > 0 else {
                throw cursor.error("expected a digit in the exponent")
            }
        }

        let text = String(decoding: cursor.bytes[start..<cursor.offset], as: UTF8.self)
        guard let number = Double(text), number.isFinite else {
            throw cursor.error("a number is out of range")
        }

        return number
    }
}
