//
//  JSONValue.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

package enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object(JSONObject)

    // MARK: - Property
    var objectValue: JSONObject? {
        guard case let .object(object) = self else { return nil }
        return object
    }

    var arrayValue: [JSONValue]? {
        guard case let .array(elements) = self else { return nil }
        return elements
    }

    var stringValue: String? {
        guard case let .string(string) = self else { return nil }
        return string
    }

    var numberValue: Double? {
        guard case let .number(number) = self else { return nil }
        return number
    }

    var boolValue: Bool? {
        guard case let .bool(bool) = self else { return nil }
        return bool
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
