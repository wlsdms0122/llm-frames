//
//  ValueStructure.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The type of a value of a look: how it is read, merged and timed. Declaring a keyframable value is declaring its
// structure; the look merge and timing walk it and hold no code for any one key.
//
// A `forms` value is one of several forms, named: a string is the `color` form, and an object is the form its `kind`
// names, a form `kind:<value>` (a gradient's `kind:linear`), its other keys the form's body. A `choice` is a preset
// choice: a string is a preset, an object whose form key names a form is that form, an object naming none is partial
// and merges over the form below, and `offNames` turn it off. A choice's form keys are `preset`, `op` and the key of
// each form it declares, a form `<key>:<value>` (an `eq` band's `type:peak`). A form's other keys are its body, whose
// structure `forms` declares for the forms that are timed, such as a filter's presets and ops, and is otherwise
// `anyValue`: a value whose structure is not declared, which merges key by key at every depth and is never timed. A
// `tuple` is a list of a fixed length whose elements each have their own structure, as a gradient stop
// `[offset, colour]`.
indirect enum ValueStructure: Sendable {
    case anyValue
    case leaf(LeafKind)
    case object(ObjectStructure)
    case map(ValueStructure)
    case list(ValueStructure)
    case tuple([ValueStructure])
    case forms([(name: String, structure: ValueStructure)])
    case choice(offNames: [String], forms: [(name: String, structure: ValueStructure)] = [])

    // MARK: - Property
    // The name of the form a string takes.
    static let colorForm = "color"

    // MARK: - Initializer
    // MARK: - Public
    // The structure of a list's element at `index`, a tuple's own at that place. A list of choices is a list whose
    // every element is that choice.
    func element(at index: Int) -> ValueStructure {
        switch self {
        case let .list(element):
            element

        case let .tuple(structures):
            structures.indices.contains(index) ? structures[index] : .anyValue

        case .choice:
            self

        case .anyValue, .leaf, .object, .map, .forms:
            .anyValue
        }
    }

    // The keys of a choice or of forms that name an object's form, those of its declared forms first. Every choice
    // takes `preset` and `op`, since a choice whose presets are not known declares no forms.
    var formKeys: [String] {
        let names: [String]
        switch self {
        case let .choice(_, forms):
            names = forms.map(\.name) + ["preset:", "op:"]

        case let .forms(forms):
            names = forms.map(\.name)

        case .anyValue, .leaf, .object, .map, .list, .tuple:
            return []
        }

        return names.reduce(into: [String]()) { keys, name in
            guard let separator = name.firstIndex(of: ":") else { return }

            let key = String(name[..<separator])
            if !keys.contains(key) {
                keys.append(key)
            }
        }
    }

    // The form a choice's or a `forms` value's object names, by the first of its form keys the object writes as a
    // name, and the object's other keys as its body.
    func form(of object: JSONObject) -> (name: String, body: JSONObject)? {
        for key in formKeys {
            guard let name = object[key]?.stringValue else { continue }

            return (key + ":" + name, JSONObject(members: object.members.filter { $0.key != key }))
        }

        return nil
    }

    // The structure of an object's or a map's member, `anyValue` for a key no object declares.
    func structure(ofMember key: String) -> ValueStructure {
        switch self {
        case let .object(object):
            object.structure(of: key) ?? .anyValue

        case let .map(element):
            element

        case .anyValue, .leaf, .list, .tuple, .forms, .choice:
            .anyValue
        }
    }

    func structure(ofForm name: String) -> ValueStructure? {
        switch self {
        case let .forms(forms):
            forms.first { $0.name == name }?.structure

        case let .choice(_, forms):
            forms.first { $0.name == name }?.structure ?? .anyValue

        case .anyValue, .leaf, .object, .map, .list, .tuple:
            nil
        }
    }

    // MARK: - Private
}
