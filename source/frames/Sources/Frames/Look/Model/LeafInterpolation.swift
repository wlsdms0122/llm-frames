//
//  LeafInterpolation.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// How a timed leaf moves between two keyframes: in a straight line, or geometrically (in log space), for a positive
// value heard or seen by its ratio, as a frequency or a band's `q` is.
enum LeafInterpolation: Equatable, Sendable {
    case linear
    case geometric

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func value(
        of keyframes: [Keyframe<LeafValue>],
        at time: Double
    ) -> LeafValue {
        switch self {
        case .linear:
            return KeyframeTrack(keyframes: keyframes).value(at: time) ?? keyframes[0].value

        case .geometric:
            let track = KeyframeTrack(keyframes: keyframes.map { keyframe in
                Keyframe(at: keyframe.at, value: GeometricLeafValue(keyframe.value), ease: keyframe.ease)
            })
            return track.value(at: time)?.value ?? keyframes[0].value
        }
    }

    // MARK: - Private
}
