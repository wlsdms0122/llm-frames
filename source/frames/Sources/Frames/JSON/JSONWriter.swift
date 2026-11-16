//
//  JSONWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Writes a value as JSON text that reads back to the same value, the same bytes for the same value. Members keep the
// order the object holds them in. An object and a list of lists or objects put each member or element on its own
// line, indented by two spaces, and a list of plain values stays on one line. A number is the shortest decimal that
// reads back to the same `Double`, with no exponent and no fraction when it is whole, and `-0` is `0`.
struct JSONWriter: Sendable {
    // MARK: - Property
    private static let indent = "  "

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // The text ends with a line break, as a file does.
    func write(_ value: JSONValue) -> String {
        var text = ""
        write(value, depth: 0, into: &text)

        return text + "\n"
    }

    func number(_ number: Double) -> String {
        // A plan that reaches a non-finite number is a fault of resolve, not of the document.
        precondition(number.isFinite, "JSON has no form for \(number)")

        // `description` is the shortest decimal that reads back to the same `Double`, but may use an exponent.
        let written = number.description
        let parts = written.split(separator: "e", maxSplits: 1)
        let exponent = parts.count == 2 ? Int(parts[1]) ?? 0 : 0
        let mantissa = parts[0].hasPrefix("-") ? parts[0].dropFirst() : parts[0]
        let point = mantissa.firstIndex(of: ".") ?? mantissa.endIndex
        let whole = mantissa[mantissa.startIndex..<point]
        let fraction = point < mantissa.endIndex ? mantissa[mantissa.index(after: point)...] : ""

        // The digits with no point, and how many of them stand before the point.
        var digits = Array(whole + fraction)
        var pointOffset = whole.count + exponent
        while let first = digits.first, first == "0" {
            digits.removeFirst()
            pointOffset -= 1
        }
        while let last = digits.last, last == "0" {
            digits.removeLast()
        }
        guard !digits.isEmpty else { return "0" }

        let sign = number < 0 ? "-" : ""
        if pointOffset <= 0 {
            return sign + "0." + String(repeating: "0", count: -pointOffset) + String(digits)
        }
        if pointOffset >= digits.count {
            return sign + String(digits) + String(repeating: "0", count: pointOffset - digits.count)
        }

        return sign + String(digits[..<pointOffset]) + "." + String(digits[pointOffset...])
    }

    // Quotes, backslashes and control characters are escaped, and every other character is written as itself.
    func string(_ string: String) -> String {
        var text = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"":
                text += "\\\""

            case "\\":
                text += "\\\\"

            case "\u{08}":
                text += "\\b"

            case "\u{0C}":
                text += "\\f"

            case "\n":
                text += "\\n"

            case "\r":
                text += "\\r"

            case "\t":
                text += "\\t"

            case _ where scalar.value < 0x20:
                let digits = String(scalar.value, radix: 16, uppercase: true)
                text += "\\u" + String(repeating: "0", count: 4 - digits.count) + digits

            default:
                text.unicodeScalars.append(scalar)
            }
        }

        return text + "\""
    }

    // MARK: - Private
    private func write(
        _ value: JSONValue,
        depth: Int,
        into text: inout String
    ) {
        switch value {
        case .null:
            text += "null"

        case let .bool(bool):
            text += bool ? "true" : "false"

        case let .number(number):
            text += self.number(number)

        case let .string(string):
            text += self.string(string)

        case let .array(elements):
            guard !elements.isEmpty else {
                text += "[]"
                return
            }
            guard elements.contains(where: isNested) else {
                text += "["
                for (index, element) in elements.enumerated() {
                    text += index == 0 ? "" : ", "
                    write(element, depth: depth, into: &text)
                }
                text += "]"
                return
            }

            text += "[\n"
            for (index, element) in elements.enumerated() {
                text += String(repeating: Self.indent, count: depth + 1)
                write(element, depth: depth + 1, into: &text)
                text += index == elements.count - 1 ? "\n" : ",\n"
            }
            text += String(repeating: Self.indent, count: depth) + "]"

        case let .object(object):
            guard !object.members.isEmpty else {
                text += "{}"
                return
            }

            text += "{\n"
            for (index, member) in object.members.enumerated() {
                text += String(repeating: Self.indent, count: depth + 1) + string(member.key) + ": "
                write(member.value, depth: depth + 1, into: &text)
                text += index == object.members.count - 1 ? "\n" : ",\n"
            }
            text += String(repeating: Self.indent, count: depth) + "}"
        }
    }

    private func isNested(_ value: JSONValue) -> Bool {
        switch value {
        case .array, .object:
            true

        case .null, .bool, .number, .string:
            false
        }
    }
}
