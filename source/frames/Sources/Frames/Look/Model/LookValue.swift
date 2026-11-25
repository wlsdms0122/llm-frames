//
//  LookValue.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// One layer's value of a look, read by its structure with its shorthands expanded. `unset` is a leaf that takes the
// value below (`null`, or a leaf `true` names), and `off` turns the value below off (`false`, `"none"`). A form holds
// its name: a `forms` value's (`color`, `kind:linear`), or a choice's `preset:<name>`, `kind:<name>` or `preset` for a
// preset entry that names no preset; a choice object that names no form is a partial `object`.
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

    // A choice's value that changes the form below it: an object that names no form, or a preset entry that names no
    // preset.
    var isPartialChoice: Bool {
        switch self {
        case .object, .form(ValueStructure.presetKind, _):
            true

        case .unset, .off, .leaf, .list, .form:
            false
        }
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

        case let (.off, .choice(offNames, _, _)):
            return .string(offNames.first ?? "none")

        case (.off, _):
            return .bool(false)

        case let (.leaf(value), _):
            return value

        case let (.list(elements), .list(element)):
            return .array(elements.compactMap { $0.json(as: element) })

        case let (.list(elements), .tuple(structures)):
            return .array(zip(elements, structures).compactMap { $0.json(as: $1) })

        case let (.list(elements), _):
            return .array(elements.compactMap { $0.json(as: structure) })

        case let (.object(members), _):
            return .object(JSONObject(members: members.compactMap { member in
                member.value.json(as: structure.structure(ofMember: member.key)).map {
                    JSONMember(key: member.key, value: $0)
                }
            }))

        case let (.form(name, body), .choice(_, _, naming)):
            return choiceJSON(name: name, body: body, naming: naming)

        // A colour is its form's body, and a named form writes its name beside its body's keys.
        case let (.form(name, body), _):
            let inner = body.json(as: structure.structure(ofForm: name) ?? .anyValue) ?? .null
            guard let separator = name.firstIndex(of: ":") else { return inner }

            let key = String(name[..<separator])
            let named = JSONMember(key: key, value: .string(String(name[name.index(after: separator)...])))
            return .object(JSONObject(members: [named] + (inner.objectValue?.members ?? [])))
        }
    }

    // MARK: - Private
    private func choiceJSON(
        name: String,
        body: LookValue,
        naming: ChoiceNaming
    ) -> JSONValue {
        let members = body.json(as: .anyValue)?.objectValue?.members ?? []
        let presetKind = naming == .kind ? [JSONMember(key: "kind", value: .string(ValueStructure.presetKind))] : []
        guard let separator = name.firstIndex(of: ":") else {
            let kind = name == ValueStructure.presetKind ? presetKind : []
            return .object(JSONObject(members: kind + members))
        }

        let key = String(name[..<separator])
        let value = String(name[name.index(after: separator)...])
        guard key == "preset" else {
            return .object(JSONObject(members: [JSONMember(key: key, value: .string(value))] + members))
        }
        guard !members.isEmpty else { return .string(value) }

        return .object(JSONObject(members: presetKind + [JSONMember(key: key, value: .string(value))] + members))
    }
}
