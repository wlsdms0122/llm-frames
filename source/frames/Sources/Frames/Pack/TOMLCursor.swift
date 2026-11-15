//
//  TOMLCursor.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Reads the one value on the right of a `key =`. A `#` starts a comment only outside a string.
struct TOMLCursor {
    // MARK: - Property
    private let characters: [Character]
    private let file: String
    private let line: Int
    private var index = 0

    // MARK: - Initializer
    init(
        text: String,
        file: String,
        line: Int
    ) {
        self.characters = Array(text)
        self.file = file
        self.line = line
    }

    // MARK: - Public
    mutating func value() throws -> JSONValue {
        skipWhitespace()
        guard let head = peek() else { throw error("missing value") }

        switch head {
        case "\"":
            return .string(try string())

        case "[":
            return .array(try array())

        default:
            return try literal()
        }
    }

    mutating func expectEnd() throws {
        skipWhitespace()
        guard let head = peek(), head != "#" else { return }

        throw error("unexpected text after the value: \(String(characters[index...]))")
    }

    // MARK: - Private
    private mutating func string() throws -> String {
        advance()

        var result = ""
        while let character = peek() {
            advance()

            switch character {
            case "\"":
                return result

            case "\\":
                result.append(try escape())

            default:
                result.append(character)
            }
        }

        throw error("a string is not closed")
    }

    private mutating func escape() throws -> Character {
        guard let character = peek() else { throw error("a string ends with a backslash") }

        advance()
        switch character {
        case "n":
            return "\n"

        case "t":
            return "\t"

        case "\"":
            return "\""

        case "\\":
            return "\\"

        default:
            throw error("unknown escape \\\(character)")
        }
    }

    private mutating func array() throws -> [JSONValue] {
        advance()

        var elements: [JSONValue] = []
        while true {
            skipWhitespace()
            guard let head = peek() else { throw error("a list is not closed") }

            if head == "]" {
                advance()
                return elements
            }

            elements.append(try value())
            skipWhitespace()
            if peek() == "," {
                advance()
            } else if peek() != "]" {
                throw error("expected \",\" between the elements of a list")
            }
        }
    }

    // Only integers, true and false are written unquoted, so a date, a float or a bare word does not pass for one.
    private mutating func literal() throws -> JSONValue {
        var word = ""
        while let character = peek(), !character.isWhitespace, ![",", "]", "#"].contains(character) {
            word.append(character)
            advance()
        }

        switch word {
        case "true":
            return .bool(true)

        case "false":
            return .bool(false)

        case "":
            throw error("unreadable value")

        default:
            guard let integer = Int(word) else {
                throw error("unquoted value \(word). Write a string as \"\(word)\"")
            }

            return .number(Double(integer))
        }
    }

    private func peek() -> Character? {
        index < characters.count ? characters[index] : nil
    }

    private mutating func advance() {
        index += 1
    }

    private mutating func skipWhitespace() {
        while let character = peek(), character.isWhitespace {
            advance()
        }
    }

    private func error(_ reason: String) -> PackError {
        .manifestSyntax(file: file, line: line, reason: reason)
    }
}
