//
//  MixValueSampler.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Writes a sound's timed leaf as a segment's value over its heard range: a number where it holds there, otherwise an
// envelope with a point where a gain envelope has them, both ends, every keyframe and every frame time inside a span
// that moves, each sampled as its leaf interpolates. `clock` maps outermost sequence time to the sound's.
struct MixValueSampler: Sendable {
    // MARK: - Property
    private let clock: TimeMap
    private let heard: TimeRange
    private let fps: Double

    // MARK: - Initializer
    init(
        clock: TimeMap,
        heard: TimeRange,
        fps: Double
    ) {
        self.clock = clock
        self.heard = heard
        self.fps = fps
    }

    // MARK: - Public
    func value(
        _ timed: TimedValue?,
        as kind: LeafKind
    ) -> MixValue? {
        guard case let .track(keyframes) = timed, let timed else { return nil }

        let numbers = keyframes.compactMap { keyframe -> Keyframe<Double>? in
            guard case let .number(number) = keyframe.value else { return nil }

            return Keyframe(at: keyframe.at, value: number, ease: keyframe.ease)
        }
        let times = EnvelopeTimes(keyframes: numbers).mapped(through: clock).times(over: heard, fps: fps)
        let points = times.compactMap { time in
            timed.sampled(at: clock.clipTime(atSequenceTime: time), as: .leaf(kind)).number.map { value in
                EnvelopePoint(time: time, value: value)
            }
        }
        guard let first = points.first else { return nil }
        guard points.contains(where: { $0.value != first.value }) else { return .constant(first.value) }

        return .envelope(points)
    }

    // MARK: - Private
}
