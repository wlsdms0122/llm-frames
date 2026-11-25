//
//  ValueType+Structure.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The key check's type of a look value, read from its structure, so the key check and the look merge read one
// declaration of its keys and domains. `kind` names the value in messages. A number leaf, and each number of a list
// leaf, takes its leaf's domain, which the key check stops in the layer that writes it, as timing and the theme merge
// stop through `NumberDomain.check` where they build the value: a theme layer's value that a stronger layer replaces
// reaches neither, so only the key check stops it. A keyframe's number takes any number here (`ClipKeyTable`), since
// timing checks it against its domain or, where two keyframes or more write the leaf, its sampled domain. Without
// `checksDomains` every number is any number: a filter op's parameters are checked by `PresetReader.checkRanges` and
// an audio op's by `ValueStructure.checkDomains(of:place:sampled:)`, each of which lets a leaf a sampled argument fills
// take the values its samples take.
extension ValueType {
    // MARK: - Property
    // The prefix of a `forms` value's form that an object's `kind` names.
    private static let kindForm = "kind:"

    // MARK: - Initializer
    // A form other than a string's is an object of the kinds of a `KindTable`, its `kind` naming the form beside the
    // keys of the form's body, and messages call it by that name before `kind`, as `linear gradient`. A list of tuples
    // is a gradient's stops, the one tuple a look declares, and a choice inside a look is an `eq` band, an object its
    // kind's table checks.
    init(
        structure: ValueStructure,
        kind: String,
        checksDomains: Bool = true
    ) {
        switch structure {
        case .anyValue, .tuple:
            self = .anyValue

        case let .leaf(leaf):
            self = Self.type(of: leaf, checksDomain: checksDomains)

        // An object with a name shorthand also takes the names of the key it names, as a stroke's end takes its preset.
        case let .object(object):
            let table = ValueType.object(ObjectTable(structure: object, kind: kind, checksDomains: checksDomains))
            let names = object.shorthands.compactMap { shorthand -> ValueType? in
                guard case let .name(key) = shorthand, let named = object.structure(of: key) else { return nil }

                return ValueType(structure: named, kind: kind, checksDomains: checksDomains)
            }
            self = names.isEmpty ? table : .oneOf(names + [table])

        case let .map(element):
            self = .map(ValueType(structure: element, kind: kind, checksDomains: checksDomains), kind: kind)

        case .list(.tuple):
            self = .stops(isKeyframed: false)

        case let .list(element):
            self = .list(ValueType(structure: element, kind: kind, checksDomains: checksDomains))

        case let .forms(forms):
            let tables = forms.reduce(into: [String: ObjectTable]()) { tables, form in
                guard form.name.hasPrefix(Self.kindForm), case let .object(body) = form.structure else { return }

                let name = String(form.name.dropFirst(Self.kindForm.count))
                let table = ObjectTable(structure: body, kind: "\(name) \(kind)", checksDomains: checksDomains)
                tables[name] = ObjectTable(
                    kind: table.kind,
                    rules: [KeyRule("kind", .literal([name]), isRequired: true)] + table.rules,
                    groups: table.groups
                )
            }
            let colors = forms.contains { $0.name == ValueStructure.colorForm } ? [ValueType.color] : []
            let objects = tables.isEmpty ? [] : [ValueType.kinds(KindTable(kind: kind, tables: tables))]
            let types = colors + objects
            self = types.count == 1 ? types[0] : .oneOf(types)

        case .choice:
            self = .anyObject
        }
    }

    // A look value as a layer writes it over the value below, as a clip or a style does: `false` turns an object or a
    // form off, and an object also takes its shorthands, `true` for the value below and a colour for its colour.
    init(
        written structure: ValueStructure,
        kind: String
    ) {
        let value = ValueType(structure: structure, kind: kind)
        let forms = if case let .oneOf(types) = value { types } else { [value] }
        switch structure {
        case let .object(object):
            let on = object.shorthands.contains(.on)
            let shorthands = object.shorthands.compactMap(Self.type(of:))
            self = .oneOf([on ? .bool : .exactly(.bool(false))] + shorthands + forms)

        case .forms:
            self = .oneOf([.exactly(.bool(false))] + forms)

        case .anyValue, .leaf, .map, .list, .tuple, .choice:
            self = value
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A colour for its colour and a point for its point, nil for `true`, which `on` takes, and a name, which the object
    // itself takes.
    private static func type(of shorthand: ObjectShorthand) -> ValueType? {
        switch shorthand {
        case .on, .name:
            nil

        case .color:
            .color

        case .point:
            AreaKeyTable.point
        }
    }

    private static func type(
        of leaf: LeafKind,
        checksDomain: Bool
    ) -> ValueType {
        let domain = checksDomain ? leaf.domain : .any

        switch leaf.form {
        case .color:
            return .color

        case .name:
            return leaf.names.map { .literal($0) } ?? .name

        case .boolean:
            return .bool

        case .file:
            return .name

        case let .numbers(count):
            return .numbers(count, domain)

        case .corners:
            return .oneOf([.number(domain), .numbers(4, domain)])

        case .number, .staticNumber:
            return .number(domain)
        }
    }
}
