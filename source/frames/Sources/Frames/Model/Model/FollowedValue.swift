//
//  FollowedValue.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A resolved value of a clip's geometry that a track can carry (FRAMES-19 Timed values): keyframes in sequence time, or
// a static value of a tracked clip true on the track's frame (FRAMES-12 The track). A static value holds at every time,
// and a track does not bring it back, since its motion is the identity on that frame. A static value of a clip that is
// not tracked, or one searched at the clip's instant, is one keyframe there.
enum FollowedValue<Value: Equatable & Sendable>: Equatable, Sendable {
    case onTrackFrame(Value)
    case keyframes([Keyframe<Value>])

    // MARK: - Property
    // Every value written: the static value, or each keyframe's in the order written.
    var values: [Value] {
        switch self {
        case let .onTrackFrame(value):
            [value]

        case let .keyframes(keyframes):
            keyframes.map(\.value)
        }
    }

    // The time of each keyframe, none for a static value.
    var keyframeTimes: [Double] {
        switch self {
        case .onTrackFrame:
            []

        case let .keyframes(keyframes):
            keyframes.map(\.at)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    func value(at time: Double) -> Value where Value: Interpolable {
        switch self {
        case let .onTrackFrame(value):
            value

        case let .keyframes(keyframes):
            keyframes.value(at: time)
        }
    }

    // The same value with each value transformed alike, at whatever time it holds.
    func mapValues<Other: Equatable & Sendable>(_ transform: (Value) throws -> Other) rethrows -> FollowedValue<Other> {
        switch self {
        case let .onTrackFrame(value):
            .onTrackFrame(try transform(value))

        case let .keyframes(keyframes):
            .keyframes(try keyframes.map { Keyframe(at: $0.at, value: try transform($0.value), ease: $0.ease) })
        }
    }

    // The same value with each keyframe transformed at its own time, and a static value by `onTrackFrame`.
    func carried<Other: Equatable & Sendable>(
        keyframe transform: (Value, Double) throws -> Other,
        onTrackFrame: (Value) throws -> Other
    ) rethrows -> FollowedValue<Other> {
        switch self {
        case let .onTrackFrame(value):
            .onTrackFrame(try onTrackFrame(value))

        case let .keyframes(keyframes):
            .keyframes(try keyframes.map { Keyframe(at: $0.at, value: try transform($0.value, $0.at), ease: $0.ease) })
        }
    }

    // MARK: - Private
}
