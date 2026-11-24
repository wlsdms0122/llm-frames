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

        case let .choice(offNames, forms):
            return choice(json, offNames: offNames, forms: forms, as: structure)
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

        case .string:
            for shorthand in structure.shorthands {
                switch shorthand {
                case let .color(key), let .name(key):
                    return .object([LookMember(key: key, value: .leaf(json))])

                case .on, .point:
                    continue
                }
            }
            return .leaf(json)

        case .array:
            return point(json, as: structure) ?? .leaf(json)

        // An object that writes keys, none of them the structure's, is a named point where the structure takes one.
        case let .object(object):
            let isPoint = !object.keys.isEmpty && !object.keys.contains { structure.structure(of: $0) != nil }
            if isPoint, let point = point(json, as: structure) {
                return point
            }

            return .object(object.members.map { member in
                let child = structure.structure(of: member.key) ?? .anyValue
                return LookMember(key: member.key, value: value(of: member.value, as: child))
            })

        default:
            return .leaf(json)
        }
    }

    // A point written for an object that takes one names that object's point alone.
    private func point(
        _ json: JSONValue,
        as structure: ObjectStructure
    ) -> LookValue? {
        for case let .point(key) in structure.shorthands {
            return .object([LookMember(key: key, value: .leaf(json))])
        }

        return nil
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

    // A form's body is read by the structure its form declares, and a partial choice's keys by the structure of the
    // first form that declares each, so a list in it is a list wherever it is written.
    private func choice(
        _ json: JSONValue,
        offNames: [String],
        forms: [(name: String, structure: ValueStructure)],
        as structure: ValueStructure
    ) -> LookValue {
        switch json {
        case let .string(name):
            return offNames.contains(name) ? .off : .form("preset:" + name, .object([]))

        case let .array(elements):
            return .list(elements.map { choice($0, offNames: offNames, forms: forms, as: structure) })

        case let .object(object):
            if let form = structure.form(of: object) {
                let body = structure.structure(ofForm: form.name) ?? .anyValue
                return .form(form.name, value(of: .object(form.body), as: body))
            }
            guard !object.contains("entrance"), !object.contains("exit") else {
                return .form("sides", free(json))
            }

            return .object(object.members.map { member in
                let structure = forms.lazy.compactMap { form -> ValueStructure? in
                    guard case let .object(body) = form.structure else { return nil }

                    return body.structure(of: member.key)
                }.first
                return LookMember(key: member.key, value: value(of: member.value, as: structure ?? .anyValue))
            })

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
