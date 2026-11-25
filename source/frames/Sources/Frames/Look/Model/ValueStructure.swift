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
// and merges over the form below, and `offNames` turn it off. Its naming says which key names a form: `preset`, a form
// `preset:<name>`, or `kind`, a form `kind:<name>` (a filter's op `kind:blur`, an `eq` band's `kind:peak`), with
// `preset:<name>` for an entry of kind `preset` and `preset` for one that names no preset. A form's other keys are its
// body, whose structure `forms` declares for the forms that are timed, such as a filter's presets and ops, and is
// otherwise `anyValue`: a value whose structure is not declared, which merges key by key at every depth and is never
// timed. A `tuple` is a list of a fixed length whose elements each have their own structure, as a gradient stop
// `[offset, colour]`.
indirect enum ValueStructure: Sendable {
    case anyValue
    case leaf(LeafKind)
    case object(ObjectStructure)
    case map(ValueStructure)
    case list(ValueStructure)
    case tuple([ValueStructure])
    case forms([(name: String, structure: ValueStructure)])
    case choice(offNames: [String], forms: [(name: String, structure: ValueStructure)] = [], naming: ChoiceNaming)

    // MARK: - Property
    // The name of the form a string takes.
    static let colorForm = "color"
    // The kind of a preset entry, and the form of one that names no preset, which changes the preset entry below it.
    static let presetKind = "preset"

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

    // The keys that name an object's form: a choice's by its naming, and a `forms` value's from its declared forms.
    var formKeys: [String] {
        switch self {
        case let .choice(_, _, naming):
            return naming == .kind ? ["kind"] : ["preset"]

        case let .forms(forms):
            return forms.map(\.name).reduce(into: [String]()) { keys, name in
                guard let separator = name.firstIndex(of: ":") else { return }

                let key = String(name[..<separator])
                if !keys.contains(key) {
                    keys.append(key)
                }
            }

        case .anyValue, .leaf, .object, .map, .list, .tuple:
            return []
        }
    }

    // The form a choice's or a `forms` value's object names, and the object's other keys as its body. A choice's
    // object of kind `preset` names its preset's form, and none where it names no preset, as one without `kind` does.
    // A `forms` value's object names the form by the first of its form keys it writes as a name.
    func form(of object: JSONObject) -> (name: String, body: JSONObject)? {
        switch self {
        case let .choice(_, _, naming):
            if naming == .kind, let kind = object["kind"]?.stringValue, kind != Self.presetKind {
                return ("kind:" + kind, JSONObject(members: object.members.filter { $0.key != "kind" }))
            }
            guard let preset = object["preset"]?.stringValue else { return nil }

            return (
                "preset:" + preset,
                JSONObject(members: object.members.filter { $0.key != "kind" && $0.key != "preset" })
            )

        case .forms:
            for key in formKeys {
                guard let name = object[key]?.stringValue else { continue }

                return (key + ":" + name, JSONObject(members: object.members.filter { $0.key != key }))
            }

            return nil

        case .anyValue, .leaf, .object, .map, .list, .tuple:
            return nil
        }
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

        case let .choice(_, forms, _):
            forms.first { $0.name == name }?.structure ?? .anyValue

        case .anyValue, .leaf, .object, .map, .list, .tuple:
            nil
        }
    }

    // MARK: - Private
}
