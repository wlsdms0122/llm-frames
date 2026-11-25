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
// to change, but one named `presetOverNone`, whose off name is the choice of nothing, stands for what it writes
// without `args`. A preset entry that names no preset changes a preset entry, and over an entry of another kind it
// stops.
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
        try merge(under, over, as: structure, place: place, byElement: false)
    }

    // A keyframe's value over the merged value. A keyframe's list has the length of the list it writes, so it merges
    // element by element, where a layer's list replaces the one below whole.
    func merge(
        keyframe: LookValue,
        over merged: LookValue,
        as structure: ValueStructure,
        place: Place
    ) throws -> LookValue {
        try merge(merged, keyframe, as: structure, place: place, byElement: true)
    }

    // Every key the structure requires, wherever the value holds an object of it, has a value after the merge, and no
    // list of lengths it keeps from zeros holds only zeros.
    func checkRequired(
        in value: LookValue,
        as structure: ValueStructure,
        place: Place
    ) throws {
        try check(value, as: structure, place: place, isRequired: true, isNonZero: true)
    }

    // `checkRequired` for a clip's merged value under its keyframes. A keyframe gives a leaf at every instant from its
    // own, so a required key is checked with every keyframe merged over the merged value; a keyframe's list at its own
    // instant is its own over the merged value's, so lengths are checked to be not all 0 in the merged value and in
    // each keyframe merged over it alone.
    func checkRequired(
        in merged: LookValue,
        keyframes: [PropertyKeyframe<LookValue>],
        as structure: ValueStructure,
        place: LookPlace
    ) throws {
        let given = try keyframes.reduce(merged) { given, keyframe in
            try merge(keyframe: keyframe.value, over: given, as: structure, place: place.keyframe(keyframe.index))
        }
        try check(given, as: structure, place: place.written, isRequired: true, isNonZero: false)
        try check(merged, as: structure, place: place.written, isRequired: false, isNonZero: true)
        for keyframe in keyframes {
            let keyframePlace = place.keyframe(keyframe.index)
            let value = try merge(keyframe: keyframe.value, over: merged, as: structure, place: keyframePlace)
            try check(value, as: structure, place: keyframePlace, isRequired: false, isNonZero: true)
        }
    }

    // MARK: - Private
    private func check(
        _ value: LookValue,
        as structure: ValueStructure,
        place: Place,
        isRequired: Bool,
        isNonZero: Bool
    ) throws {
        switch (value, structure) {
        case let (.object(members), .object(object)):
            for key in object.required where isRequired && (value[key] ?? .unset) == .unset {
                throw LookError.missingLeaf(place: place, key: key)
            }
            for key in object.nonZero where isNonZero {
                guard
                    case let .list(elements)? = value[key],
                    !elements.isEmpty,
                    elements.allSatisfy({ element in element == .leaf(.number(0)) })
                else { continue }

                throw LookError.allZero(place: place.appending(key: key))
            }
            for member in members {
                guard let child = object.structure(of: member.key) else { continue }

                try check(
                    member.value,
                    as: child,
                    place: place.appending(key: member.key),
                    isRequired: isRequired,
                    isNonZero: isNonZero
                )
            }

        case let (.object(members), .map(element)):
            for member in members {
                try check(
                    member.value,
                    as: element,
                    place: place.appending(key: member.key),
                    isRequired: isRequired,
                    isNonZero: isNonZero
                )
            }

        case let (.list(elements), .list), let (.list(elements), .tuple), let (.list(elements), .choice):
            for (index, value) in elements.enumerated() {
                try check(
                    value,
                    as: structure.element(at: index),
                    place: place.appending(index: index),
                    isRequired: isRequired,
                    isNonZero: isNonZero
                )
            }

        case let (.form(name, body), .forms), let (.form(name, body), .choice):
            try check(
                body,
                as: structure.structure(ofForm: name) ?? .anyValue,
                place: place,
                isRequired: isRequired,
                isNonZero: isNonZero
            )

        default:
            return
        }
    }

    private func merge(
        _ under: LookValue?,
        _ over: LookValue,
        as structure: ValueStructure,
        place: Place,
        byElement: Bool
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
            if case let .choice(_, _, naming) = structure, over.isPartialChoice {
                guard naming == .presetOverNone, over["args"] == nil else { throw LookError.nothingBelow(place: place) }
            }
            return over
        }

        switch (structure, under, over) {
        case let (.choice, .form(name, body), .object):
            let form = structure.structure(ofForm: name) ?? .anyValue
            return .form(name, try mergeObjects(body, over, as: form, place: place, byElement: byElement))

        case let (.choice, .form(name, body), .form(ValueStructure.presetKind, changes)):
            guard name.hasPrefix(ValueStructure.presetKind + ":") else {
                throw LookError.presetEntryOverKind(place: place, kind: String(name.drop { $0 != ":" }.dropFirst()))
            }

            let form = structure.structure(ofForm: name) ?? .anyValue
            return .form(name, try mergeObjects(body, changes, as: form, place: place, byElement: byElement))

        case (.choice, .list, _) where over.isPartialChoice:
            throw LookError.partialOverList(place: place)

        case let (_, .form(underName, underBody), .form(overName, overBody)):
            // A preset named alone is read as a form with no other keys, and it replaces a choice of that preset whole.
            guard underName == overName, overBody != .object([]) else { return over }

            let form = structure.structure(ofForm: overName) ?? .anyValue
            return .form(overName, try merge(underBody, overBody, as: form, place: place, byElement: byElement))

        case (.object, .object, .object), (.map, .object, .object), (.anyValue, .object, .object):
            return try mergeObjects(under, over, as: structure, place: place, byElement: byElement)

        case let (_, .list(elements), .list(others)) where byElement && elements.count == others.count:
            return .list(try zip(elements, others).enumerated().map { index, pair in
                try merge(
                    pair.0,
                    pair.1,
                    as: structure.element(at: index),
                    place: place.appending(index: index),
                    byElement: true
                )
            })

        default:
            return over
        }
    }

    private func mergeObjects(
        _ under: LookValue,
        _ over: LookValue,
        as structure: ValueStructure,
        place: Place,
        byElement: Bool
    ) throws -> LookValue {
        try over.members.reduce(under) { merged, member in
            let child = structure.structure(ofMember: member.key)
            let partners = if case let .object(object) = structure { object.partners(of: member.key) } else { [String]() }
            // A leaf only keyframes write is `unset` in the clip's own layer and still replaces its partners, so
            // keyframes of a stroke's `color` take a colour paint over a style's gradient.
            let cleared = partners.reduce(merged) { $0.setting($1, to: nil) }
            let value = try merge(
                cleared[member.key],
                member.value,
                as: child,
                place: place.appending(key: member.key),
                byElement: byElement
            )

            return cleared.setting(member.key, to: value)
        }
    }
}
