//
//  TimedValue.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A keyframable value as resolve gives it: its structure, each timed leaf a keyframe list in sequence time, and each
// static leaf its value. A leaf of numbers is a list of keyframe lists where its elements are timed one by one. `off`
// is a value that is off.
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

    // Each timed leaf at a time outside a sample of a frame with motion blur, as resolve and the mix plan read it.
    func sampled(
        at time: Double,
        as structure: ValueStructure
    ) -> SampledValue {
        sampled(at: SampleTime(time), as: structure)
    }

    // Each timed leaf at `time`, clamped to its domain where it is sampled, before it is combined with anything.
    func sampled(
        at time: SampleTime,
        as structure: ValueStructure
    ) -> SampledValue {
        switch (self, structure) {
        case (.off, _):
            return .off

        case let (.fixed(value), _):
            return .fixed(value)

        case let (.track(keyframes), .leaf(kind)):
            return .leaf(kind.interpolation.value(of: keyframes, at: time).clamped(to: kind.domain))

        case let (.track(keyframes), _):
            return .leaf(LeafInterpolation.linear.value(of: keyframes, at: time))

        case let (.object(members), _):
            return .object(Dictionary(
                members.map { ($0.key, $0.value.sampled(at: time, as: structure.structure(ofMember: $0.key))) },
                uniquingKeysWith: { first, _ in first }
            ))

        case let (.list(elements), .leaf(kind)):
            let element = LeafKind(form: .number, domain: kind.domain, interpolation: kind.interpolation)
            let numbers = elements.compactMap { $0.sampled(at: time, as: .leaf(element)).number }
            return .leaf(.numbers(numbers))

        case let (.list(elements), .list(element)):
            return .list(elements.map { $0.sampled(at: time, as: element) })

        case let (.list(elements), .tuple(structures)):
            return .list(zip(elements, structures).map { $0.sampled(at: time, as: $1) })

        case let (.list(elements), _):
            return .list(elements.map { $0.sampled(at: time, as: .anyValue) })

        case let (.form(name, body), _):
            return .form(name, body.sampled(at: time, as: structure.structure(ofForm: name) ?? .anyValue))
        }
    }

    // MARK: - Private
}
