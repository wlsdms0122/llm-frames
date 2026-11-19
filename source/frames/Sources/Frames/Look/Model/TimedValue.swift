//
//  TimedValue.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A keyframable value as resolve gives it: its structure, each timed leaf a keyframe list in sequence time, and each
// static leaf its value. `off` is a value that is off.
indirect enum TimedValue: Equatable, Sendable {
    case off
    case fixed(JSONValue)
    case track([Keyframe<LeafValue>])
    case object([TimedMember])
    case list([TimedValue])
    case form(String, TimedValue)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    subscript(key: String) -> TimedValue? {
        guard case let .object(members) = self else { return nil }

        return members.first { $0.key == key }?.value
    }

    // Each timed leaf at `time`, clamped to its domain where it is sampled, before it is combined with anything.
    func sampled(
        at time: Double,
        as structure: ValueStructure
    ) -> SampledValue {
        switch (self, structure) {
        case (.off, _):
            return .off

        case let (.fixed(value), _):
            return .fixed(value)

        case let (.track(keyframes), .leaf(kind)):
            let value = KeyframeTrack(keyframes: keyframes).value(at: time) ?? keyframes[0].value
            return .leaf(value.clamped(to: kind.domain))

        case let (.track(keyframes), _):
            return .leaf(KeyframeTrack(keyframes: keyframes).value(at: time) ?? keyframes[0].value)

        case let (.object(members), _):
            return .object(Dictionary(
                members.map { ($0.key, $0.value.sampled(at: time, as: Self.structure(of: $0.key, in: structure))) },
                uniquingKeysWith: { first, _ in first }
            ))

        case let (.list(elements), .list(element)):
            return .list(elements.map { $0.sampled(at: time, as: element) })

        case let (.list(elements), _):
            return .list(elements.map { $0.sampled(at: time, as: .anyValue) })

        case let (.form(name, body), _):
            return .form(name, body.sampled(at: time, as: structure.structure(ofForm: name) ?? .anyValue))
        }
    }

    // MARK: - Private
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
