//
//  JSONValue+Written.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A message quotes a value as JSON text, the way the file says it, rather than the way Swift prints the tree.
extension JSONValue {
    // MARK: - Property
    package var written: String {
        switch self {
        case .null:
            "null"

        case let .bool(bool):
            bool ? "true" : "false"

        case let .number(number):
            number.rounded() == number && abs(number) < 1e15 ? "\(Int(number))" : "\(number)"

        case let .string(string):
            Self.quoted(string)

        case let .array(elements):
            "[\(elements.map(\.written).joined(separator: ", "))]"

        case let .object(object):
            "{\(object.members.map { "\(Self.quoted($0.key)): \($0.value.written)" }.joined(separator: ", "))}"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private static func quoted(_ string: String) -> String {
        let escaped = string.unicodeScalars.map { scalar -> String in
            switch scalar {
            case "\"":
                return "\\\""

            case "\\":
                return "\\\\"

            case "\n":
                return "\\n"

            case "\r":
                return "\\r"

            case "\t":
                return "\\t"

            case _ where scalar.value < 0x20:
                let digits = String(scalar.value, radix: 16, uppercase: true)
                return "\\u" + String(repeating: "0", count: 4 - digits.count) + digits

            default:
                return String(scalar)
            }
        }

        return "\"\(escaped.joined())\""
    }
}
