//
//  LookReader.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Reads one layer's JSON value into a look value by its structure, its shorthands expanded to the leaves they name
// and nothing more, so a value written as a shorthand and in full has one structure. The key tables have checked its
// types, so a value of another type is kept as a leaf.
struct LookReader: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func value(
        of json: JSONValue,
        as structure: ValueStructure
    ) -> LookValue {
        if case .null = json {
            return .unset
        }

        switch structure {
        case .anyValue:
            return free(json)

        case .leaf:
            return .leaf(json)

        case let .object(object):
            return self.object(json, as: object)

        case let .map(element):
            guard json.boolValue != false else { return .off }
            guard let members = json.objectValue?.members else { return .leaf(json) }

            return .object(members.map { LookMember(key: $0.key, value: value(of: $0.value, as: element)) })

        case let .list(element):
            guard let elements = json.arrayValue else { return .leaf(json) }

            return .list(elements.map { value(of: $0, as: element) })

        case let .tuple(structures):
            guard let elements = json.arrayValue, elements.count == structures.count else { return .leaf(json) }

            return .list(zip(elements, structures).map { value(of: $0, as: $1) })

        case let .forms(forms):
            return self.forms(json, as: forms)

        case let .choice(offNames, _):
            return choice(json, offNames: offNames)
        }
    }

    // MARK: - Private
    private func object(
        _ json: JSONValue,
        as structure: ObjectStructure
    ) -> LookValue {
        switch json {
        case .bool(false):
            return .off

        case .bool(true) where structure.shorthands.contains(.on):
            return .object(structure.keys.map { LookMember(key: $0.name, value: .unset) })

        case let .string(color):
            for case let .color(key) in structure.shorthands {
                return .object([LookMember(key: key, value: .leaf(.string(color)))])
            }
            return .leaf(json)

        case let .object(object):
            return .object(object.members.map { member in
                LookMember(key: member.key, value: value(of: member.value, as: structure.structure(of: member.key) ?? .anyValue))
            })

        default:
            return .leaf(json)
        }
    }

    private func forms(
        _ json: JSONValue,
        as forms: [(name: String, structure: ValueStructure)]
    ) -> LookValue {
        if json.boolValue == false {
            return .off
        }
        if json.stringValue != nil, let form = forms.first(where: { $0.name == ValueStructure.colorForm }) {
            return .form(form.name, value(of: json, as: form.structure))
        }
        guard let member = json.objectValue?.members.first, json.objectValue?.members.count == 1,
            let form = forms.first(where: { $0.name == member.key })
        else {
            return .leaf(json)
        }

        return .form(form.name, value(of: member.value, as: form.structure))
    }

    private func choice(
        _ json: JSONValue,
        offNames: [String]
    ) -> LookValue {
        switch json {
        case let .string(name):
            return offNames.contains(name) ? .off : .form("preset:" + name, .object([]))

        case let .array(elements):
            return .list(elements.map { choice($0, offNames: offNames) })

        case let .object(object):
            for key in ["preset", "op"] {
                guard let name = object[key]?.stringValue else { continue }

                let rest = object.members.filter { $0.key != key }
                return .form(key + ":" + name, free(.object(JSONObject(members: rest))))
            }
            guard !object.contains("entrance"), !object.contains("exit") else {
                return .form("sides", free(json))
            }

            return free(json)

        default:
            return .leaf(json)
        }
    }

    private func free(_ json: JSONValue) -> LookValue {
        switch json {
        case .null:
            .unset

        case let .object(object):
            .object(object.members.map { LookMember(key: $0.key, value: free($0.value)) })

        default:
            .leaf(json)
        }
    }
}
