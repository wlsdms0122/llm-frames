//
//  PlacedJSONValue.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A JSON value with its place in the file and the kind of entry it belongs to, read as the type a reader expects. A
// value of another type stops, naming its place, what was expected and what was found.
struct PlacedJSONValue: Sendable {
    // MARK: - Property
    let value: JSONValue
    let place: Place
    let kind: String

    var isNull: Bool {
        value == .null
    }

    // What the value is, as an error names what was found.
    var finding: String {
        switch value {
        case let .array(elements):
            "a list of \(elements.count)"

        case .object:
            "an object"

        default:
            value.written
        }
    }

    // MARK: - Initializer
    init(
        _ value: JSONValue,
        place: Place,
        kind: String
    ) {
        self.value = value
        self.place = place
        self.kind = kind
    }

    // MARK: - Public
    func number() throws -> Double {
        guard let number = value.numberValue else { throw wrongType("a number") }

        return number
    }

    func integer() throws -> Int {
        guard let number = value.numberValue, let integer = Int(exactly: number) else {
            throw wrongType("a whole number")
        }

        return integer
    }

    func string() throws -> String {
        guard let string = value.stringValue else { throw wrongType("a string") }

        return string
    }

    func bool() throws -> Bool {
        guard let bool = value.boolValue else { throw wrongType("true or false") }

        return bool
    }

    // Each element with its place, its index appended.
    func elements() throws -> [PlacedJSONValue] {
        guard let elements = value.arrayValue else { throw wrongType("a list") }

        return elements.indices.map { index in
            PlacedJSONValue(elements[index], place: place.appending(index: index), kind: kind)
        }
    }

    func numbers(count: Int) throws -> [Double] {
        guard
            let elements = value.arrayValue,
            elements.count == count,
            case let numbers = elements.compactMap(\.numberValue),
            numbers.count == count
        else {
            throw wrongType("a list of \(count) numbers")
        }

        return numbers
    }

    func numbers() throws -> [Double] {
        guard
            let elements = value.arrayValue,
            case let numbers = elements.compactMap(\.numberValue),
            numbers.count == elements.count
        else {
            throw wrongType("a list of numbers")
        }

        return numbers
    }

    // An object whose keys are all in `keys`, so a key resolve never writes there stops by its name. `kind` names the
    // entry it is, or it keeps the kind of the entry it is in.
    func object(
        kind: String? = nil,
        keys: [String]
    ) throws -> PlacedJSONObject {
        let kind = kind ?? self.kind
        guard let object = value.objectValue else {
            throw ModelError.wrongType(place: place, kind: kind, expected: "an object", found: finding)
        }
        if let unknown = object.keys.first(where: { !keys.contains($0) }) {
            throw ModelError.unknownKey(place: place, kind: kind, key: unknown, allowed: keys)
        }

        return PlacedJSONObject(object, place: place, kind: kind)
    }

    // The value read, or nil for `null`.
    func optional<Value>(_ read: (PlacedJSONValue) throws -> Value) throws -> Value? {
        isNull ? nil : try read(self)
    }

    // A value that is one of a fixed set of names.
    func name<Value>(
        among allowed: [String],
        _ value: (String) -> Value?
    ) throws -> Value {
        let string = try string()
        guard let value = value(string) else {
            throw ModelError.unknownValue(place: place, kind: kind, value: string, allowed: allowed)
        }

        return value
    }

    func wrongType(_ expected: String) -> ModelError {
        .wrongType(place: place, kind: kind, expected: expected, found: finding)
    }

    // MARK: - Private
}
