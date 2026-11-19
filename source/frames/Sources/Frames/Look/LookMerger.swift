//
//  LookMerger.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The look merge: one rule for every layer of a look, a stronger theme over a weaker one, a clip's choice over the
// theme's default, a clip's own layer over its style, so a layer may change the structure below it. Objects merge key
// by key at every depth; every other value replaces the one under it; a value of another form, or a choice of another
// preset, replaces it whole; keys that are one leaf replace each other; `unset` keeps the value below and `off` turns
// it off. Over `off` or no value an upper value stands alone, and a partial choice there stops, since it has nothing
// to change.
struct LookMerger: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `layers` run from the weakest. `place` is where the strongest layer writes the value.
    func merge(
        _ layers: [LookValue?],
        as structure: ValueStructure,
        place: Place
    ) throws -> LookValue? {
        try layers.reduce(nil) { under, over in
            guard let over else { return under }

            return try merge(under, over, as: structure, place: place)
        }
    }

    func merge(
        _ under: LookValue?,
        _ over: LookValue,
        as structure: ValueStructure,
        place: Place
    ) throws -> LookValue {
        switch over {
        case .unset:
            return under ?? .unset

        case .off:
            return .off

        case .leaf, .list, .object, .form:
            break
        }

        guard let under, under != .unset, under != .off else {
            if case .choice = structure, case .object = over {
                throw LookError.nothingBelow(place: place)
            }
            return over
        }

        switch (structure, under, over) {
        case let (.choice, .form(name, body), .object):
            return .form(name, try mergeObjects(body, over, as: structure.structure(ofForm: name) ?? .anyValue, place: place))

        case (.choice, .list, .object):
            throw LookError.partialOverList(place: place)

        case let (_, .form(underName, underBody), .form(overName, overBody)):
            // A preset named alone is read as a form with no other keys, and it replaces a choice of that preset whole.
            guard underName == overName, overBody != .object([]) else { return over }

            let form = structure.structure(ofForm: overName) ?? .anyValue
            return .form(overName, try merge(underBody, overBody, as: form, place: place))

        case (.object, .object, .object), (.map, .object, .object), (.anyValue, .object, .object):
            return try mergeObjects(under, over, as: structure, place: place)

        default:
            return over
        }
    }

    // Every key the structure requires, wherever the value holds an object of it, has a value after the merge, and no
    // list of lengths it keeps from zeros holds only zeros.
    func checkRequired(
        in value: LookValue,
        as structure: ValueStructure,
        place: Place
    ) throws {
        switch (value, structure) {
        case let (.object(members), .object(object)):
            for key in object.required where (value[key] ?? .unset) == .unset {
                throw LookError.missingLeaf(place: place, key: key)
            }
            for key in object.nonZero {
                guard
                    case let .list(elements)? = value[key],
                    !elements.isEmpty,
                    elements.allSatisfy({ element in element == .leaf(.number(0)) })
                else { continue }

                throw LookError.allZero(place: place.appending(key: key))
            }
            for member in members {
                guard let child = object.structure(of: member.key) else { continue }

                try checkRequired(in: member.value, as: child, place: place.appending(key: member.key))
            }

        case let (.object(members), .map(element)):
            for member in members {
                try checkRequired(in: member.value, as: element, place: place.appending(key: member.key))
            }

        case let (.list(elements), .list(element)):
            for (index, value) in elements.enumerated() {
                try checkRequired(in: value, as: element, place: place.appending(index: index))
            }

        case let (.form(name, body), .forms):
            try checkRequired(in: body, as: structure.structure(ofForm: name) ?? .anyValue, place: place)

        default:
            return
        }
    }

    // MARK: - Private
    private func mergeObjects(
        _ under: LookValue,
        _ over: LookValue,
        as structure: ValueStructure,
        place: Place
    ) throws -> LookValue {
        try over.members.reduce(under) { merged, member in
            let child = childStructure(of: member.key, in: structure)
            let partners = if case let .object(object) = structure { object.partners(of: member.key) } else { [String]() }
            // A leaf only keyframes write is `unset` in the clip's own layer and still replaces its partners, so
            // keyframes of a stroke's `color` take a colour paint over a style's gradient.
            let cleared = partners.reduce(merged) { $0.setting($1, to: nil) }
            let value = try merge(cleared[member.key], member.value, as: child, place: place.appending(key: member.key))

            return cleared.setting(member.key, to: value)
        }
    }

    private func childStructure(
        of key: String,
        in structure: ValueStructure
    ) -> ValueStructure {
        switch structure {
        case let .object(object):
            object.structure(of: key) ?? .anyValue

        case let .map(element):
            element

        case .anyValue, .leaf, .list, .tuple, .forms, .choice:
            .anyValue
        }
    }
}
