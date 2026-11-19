//
//  ValueType+Structure.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The key check's type of a look value, read from its structure, so the key check and the look merge read one
// declaration of its keys and domains. `kind` names the value in messages. A domain the key check has no type for, as a
// compressor's `ratio` or a band's `frequency`, is checked by resolve alone. Without `checksDomains` every number is
// any number, for a value whose domains have another owner.
extension ValueType {
    // MARK: - Property
    // MARK: - Initializer
    // A form other than a string's is an object of one key, the form's name, whose kind is that name before `kind`,
    // as `linear gradient`. A list of tuples is a gradient's stops, the one tuple a look declares, and a choice inside
    // a look is an `eq` band, an object its type's table checks.
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

        case let .object(object):
            self = .object(ObjectTable(structure: object, kind: kind, checksDomains: checksDomains))

        case let .map(element):
            self = .map(ValueType(structure: element, kind: kind, checksDomains: checksDomains), kind: kind)

        case .list(.tuple):
            self = .stops(isKeyframed: false)

        case let .list(element):
            self = .list(ValueType(structure: element, kind: kind, checksDomains: checksDomains))

        case let .forms(forms):
            let named = forms.filter { $0.name != ValueStructure.colorForm }
            let object = ValueType.object(ObjectTable(
                kind: kind,
                rules: named.map { form in
                    KeyRule(
                        form.name,
                        ValueType(structure: form.structure, kind: "\(form.name) \(kind)", checksDomains: checksDomains)
                    )
                },
                groups: [KeyGroup(keys: named.map(\.name), isExclusive: true)]
            ))
            let types = (forms.count > named.count ? [ValueType.color] : []) + (named.isEmpty ? [] : [object])
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
            let shorthands = object.shorthands.filter { $0 != .on }.map(Self.type(of:))
            self = .oneOf([on ? .bool : .exactly(.bool(false))] + shorthands + forms)

        case .forms:
            self = .oneOf([.exactly(.bool(false))] + forms)

        case .anyValue, .leaf, .map, .list, .tuple, .choice:
            self = value
        }
    }

    // A look object a clip writes only by its shorthands, as a media clip's `border` is.
    init(shorthandsOf structure: ValueStructure) {
        let shorthands = if case let .object(object) = structure { object.shorthands } else { [ObjectShorthand]() }
        self = .oneOf(shorthands.map(Self.type(of:)))
    }

    // MARK: - Public
    // MARK: - Private
    // `true` for the value below, and a colour for its colour.
    private static func type(of shorthand: ObjectShorthand) -> ValueType {
        switch shorthand {
        case .on:
            .exactly(.bool(true))

        case .color:
            .color
        }
    }

    // A range from 0 to 1 is a fraction, and any other range is checked by resolve.
    private static func type(
        of leaf: LeafKind,
        checksDomain: Bool
    ) -> ValueType {
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
            return .numbers(count)

        case .number, .staticNumber:
            guard checksDomain else { return .number }

            switch leaf.domain {
            case .any:
                return .number

            case .positive:
                return .positiveNumber

            case .nonNegative:
                return .nonNegativeNumber

            case let .range(range) where range == 0...1:
                return .fraction

            case .range, .between:
                return .number
            }
        }
    }
}
