//
//  LookValue.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// One layer's value of a look, read by its structure with its shorthands expanded. `unset` is a leaf that takes the
// value below (`null`, or a leaf `true` names), and `off` turns the value below off (`false`, `"none"`). A form holds
// its name: a `forms` value's (`color`, `linear`), or a choice's `preset:<name>`, `op:<name>` or `sides`; a choice
// object that names no form is a partial `object`.
indirect enum LookValue: Equatable, Sendable {
    case unset
    case off
    case leaf(JSONValue)
    case object([LookMember])
    case list([LookValue])
    case form(String, LookValue)

    // MARK: - Property
    var members: [LookMember] {
        guard case let .object(members) = self else { return [] }

        return members
    }

    // MARK: - Initializer
    // MARK: - Public
    subscript(key: String) -> LookValue? {
        members.first { $0.key == key }?.value
    }

    func setting(
        _ key: String,
        to value: LookValue?
    ) -> LookValue {
        var members = members
        let index = members.firstIndex { $0.key == key }
        switch (index, value) {
        case let (.some(index), .some(value)):
            members[index] = LookMember(key: key, value: value)

        case let (.some(index), .none):
            members.remove(at: index)

        case let (.none, .some(value)):
            members.append(LookMember(key: key, value: value))

        case (.none, .none):
            break
        }

        return .object(members)
    }

    // The value written out as JSON, `nil` where it is `unset`: an `off` as `false`, or as the first off name of a
    // choice, and a preset form without other keys as its name.
    func json(as structure: ValueStructure) -> JSONValue? {
        switch (self, structure) {
        case (.unset, _):
            return nil

        case let (.off, .choice(offNames, _)):
            return .string(offNames.first ?? "none")

        case (.off, _):
            return .bool(false)

        case let (.leaf(value), _):
            return value

        case let (.list(elements), .list(element)):
            return .array(elements.compactMap { $0.json(as: element) })

        case let (.list(elements), _):
            return .array(elements.compactMap { $0.json(as: structure) })

        case let (.object(members), _):
            return .object(JSONObject(members: members.compactMap { member in
                member.value.json(as: Self.structure(of: member.key, in: structure)).map {
                    JSONMember(key: member.key, value: $0)
                }
            }))

        case let (.form(name, body), .choice):
            return choiceJSON(name: name, body: body)

        case let (.form(name, body), _):
            let inner = body.json(as: structure.structure(ofForm: name) ?? .anyValue) ?? .null
            guard name != ValueStructure.colorForm else { return inner }

            return .object(JSONObject(members: [JSONMember(key: name, value: inner)]))
        }
    }

    // MARK: - Private
    private static func structure(
        of key: String,
        in structure: ValueStructure
    ) -> ValueStructure {
        switch structure {
        case let .object(object):
            object.structure(of: key) ?? .anyValue

        case let .map(element):
            element

        case .anyValue, .leaf, .list, .forms, .choice:
            .anyValue
        }
    }

    private func choiceJSON(
        name: String,
        body: LookValue
    ) -> JSONValue {
        let members = body.json(as: .anyValue)?.objectValue?.members ?? []
        guard let separator = name.firstIndex(of: ":") else {
            return .object(JSONObject(members: members))
        }

        let key = String(name[..<separator])
        let value = String(name[name.index(after: separator)...])
        guard key != "preset" || !members.isEmpty else { return .string(value) }

        return .object(JSONObject(members: [JSONMember(key: key, value: .string(value))] + members))
    }
}
