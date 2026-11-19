//
//  TimedValueBuilder.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Timing, the second operation after the look merge. `ownLayer` makes the clip's own layer, its static value with the
// structure its keyframes give, which then merges over the look; `timed` times each leaf over the merged value: a leaf
// joins only the keyframes that write it, `null` there is the merged value's, and a leaf no keyframe writes is the
// merged value's at `instant`. Keyframes are in sequence time, and `place` is where the clip writes the key.
struct TimedValueBuilder: Sendable {
    // MARK: - Property
    private let merger = LookMerger()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func ownLayer(
        written: LookValue?,
        keyframes: [PropertyKeyframe<LookValue>],
        as structure: ValueStructure,
        place: Place
    ) throws -> LookValue? {
        var layer = written
        for keyframe in keyframes {
            let skeleton = try self.skeleton(of: keyframe.value, as: structure, place: place)
            if let layer {
                try checkAgreement(layer, skeleton, place: place)
            }
            layer = try merger.merge(skeleton, layer ?? .unset, as: structure, place: place)
        }

        return layer
    }

    func timed(
        _ merged: LookValue,
        written: LookValue?,
        keyframes: [PropertyKeyframe<LookValue>],
        as structure: ValueStructure,
        instant: Double,
        place: Place,
        leaf: (JSONValue, LeafKind) throws -> LeafValue
    ) throws -> TimedValue {
        switch (merged, structure) {
        case (.off, _):
            return .off

        case let (_, .leaf(kind)) where kind.isTimed:
            return try track(merged, written: written, keyframes: keyframes, kind: kind, instant: instant, place: place, leaf: leaf)

        case let (.leaf(value), _):
            return .fixed(value)

        case let (.object(members), _):
            let keys = members.map(\.key) + keyframes.flatMap { $0.value.members.map(\.key) }
            var timed: [TimedMember] = []
            for key in keys where !timed.contains(where: { $0.key == key }) {
                let child = Self.structure(of: key, in: structure)
                let value = try self.timed(
                    merged[key] ?? .unset,
                    written: written?[key],
                    keyframes: keyframes.compactMap { keyframe in keyframe.value[key].map(keyframe.with) },
                    as: child,
                    instant: instant,
                    place: place.appending(key: key),
                    leaf: leaf
                )
                timed.append(TimedMember(key: key, value: value))
            }
            return .object(timed)

        case let (.list(elements), _):
            let element = if case let .list(element) = structure { element } else { ValueStructure.anyValue }
            return .list(try elements.enumerated().map { index, value in
                try timed(
                    value,
                    written: written.flatMap { Self.element(index, of: $0) },
                    keyframes: keyframes.compactMap { keyframe in Self.element(index, of: keyframe.value).map(keyframe.with) },
                    as: element,
                    instant: instant,
                    place: place.appending(index: index),
                    leaf: leaf
                )
            })

        case let (.form(name, body), _):
            let bodies = keyframes.compactMap { keyframe -> PropertyKeyframe<LookValue>? in
                guard case let .form(_, value) = keyframe.value else { return nil }

                return keyframe.with(value)
            }
            let inner = try timed(
                body,
                written: written.flatMap { if case let .form(_, value) = $0 { value } else { nil } },
                keyframes: bodies,
                as: structure.structure(ofForm: name) ?? .anyValue,
                instant: instant,
                place: place,
                leaf: leaf
            )
            return .form(name, inner)

        case (.unset, _):
            return .off
        }
    }

    // MARK: - Private
    // One timed leaf: a keyframe list over the keyframes that write it, or one keyframe of the merged value.
    private func track(
        _ merged: LookValue,
        written: LookValue?,
        keyframes: [PropertyKeyframe<LookValue>],
        kind: LeafKind,
        instant: Double,
        place: Place,
        leaf: (JSONValue, LeafKind) throws -> LeafValue
    ) throws -> TimedValue {
        guard !keyframes.isEmpty else {
            guard case let .leaf(value) = merged else { return .off }

            return .track([Keyframe(at: instant, value: try leaf(value, kind))])
        }

        if case .leaf = written, keyframes.allSatisfy({ $0.value != .unset }) {
            throw LookError.staticAndKeyframed(place: place)
        }

        let values = try keyframes.map { keyframe -> Keyframe<LeafValue> in
            let json: JSONValue
            switch (keyframe.value, merged) {
            case let (.leaf(value), _), let (.unset, .leaf(value)):
                json = value

            default:
                throw LookError.nullWithoutValue(place: place)
            }

            let value = try leaf(json, kind)
            let numbers: [Double] = switch value {
            case let .number(number): [number]
            case let .numbers(numbers): numbers
            case .color: []
            }
            // A leaf two keyframes or more write is one end of a change, so it may take any value its samples take.
            let fits = keyframes.count > 1 ? kind.domain.contains : kind.domain.isSeen
            if let outside = numbers.first(where: { !fits($0) }) {
                throw LookError.outsideDomain(place: place, value: outside)
            }

            return Keyframe(at: keyframe.at, value: value, ease: keyframe.ease)
        }

        return .track(values)
    }

    // A keyframe's value with every timed leaf `unset`: the forms and list lengths it writes. A static leaf, `off`, or
    // `null` for an object or a list stops.
    private func skeleton(
        of value: LookValue,
        as structure: ValueStructure,
        place: Place
    ) throws -> LookValue {
        switch (value, structure) {
        case (.off, _):
            throw LookError.keyframedOff(place: place)

        case (.unset, .leaf), (.unset, .anyValue):
            return .unset

        case (.unset, _):
            throw LookError.nullStructure(place: place)

        case let (.leaf, .leaf(kind)):
            guard kind.isTimed else { throw LookError.keyframedStatic(place: place) }

            return .unset

        case (.leaf, _):
            return .unset

        case let (.object(members), _):
            return .object(try members.map { member in
                let child = Self.structure(of: member.key, in: structure)
                return LookMember(
                    key: member.key,
                    value: try skeleton(of: member.value, as: child, place: place.appending(key: member.key))
                )
            })

        case let (.list(elements), _):
            let element = if case let .list(element) = structure { element } else { ValueStructure.anyValue }
            return .list(try elements.enumerated().map { index, value in
                try skeleton(of: value, as: element, place: place.appending(index: index))
            })

        case let (.form(name, body), _):
            return .form(name, try skeleton(of: body, as: structure.structure(ofForm: name) ?? .anyValue, place: place))
        }
    }

    // The clip's forms and list lengths agree with each keyframe's.
    private func checkAgreement(
        _ layer: LookValue,
        _ skeleton: LookValue,
        place: Place
    ) throws {
        switch (layer, skeleton) {
        case (.off, _):
            throw LookError.keyframedOff(place: place)

        case let (.form(name, body), .form(other, inner)):
            guard name == other else { throw LookError.formsDiffer(place: place, forms: [name, other]) }

            try checkAgreement(body, inner, place: place)

        case (.unset, _), (_, .unset):
            return

        case let (.form(name, _), _), let (_, .form(name, _)):
            throw LookError.formsDiffer(place: place, forms: [name])

        case let (.list(elements), .list(others)):
            guard elements.count == others.count else {
                throw LookError.lengthsDiffer(place: place, counts: [elements.count, others.count])
            }

            for (index, pair) in zip(elements, others).enumerated() {
                try checkAgreement(pair.0, pair.1, place: place.appending(index: index))
            }

        case let (.object, .object(members)):
            for member in members {
                guard let value = layer[member.key] else { continue }

                try checkAgreement(value, member.value, place: place.appending(key: member.key))
            }

        default:
            return
        }
    }

    private static func element(
        _ index: Int,
        of value: LookValue
    ) -> LookValue? {
        guard case let .list(elements) = value, elements.indices.contains(index) else { return nil }

        return elements[index]
    }

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
}
