//
//  EnvelopeTimes.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

import Foundation

// Where an envelope needs points, on one clock: the instants where its value may bend (keyframes, the ends of fades
// and crossfades) and the spans where its value moves. Over a span where it moves the value is sampled at the frame
// rate, so straight lines stand in for eases, for the crossfade curve and for a product of ramps; where it holds, the
// points at its bends are exact.
struct EnvelopeTimes: Equatable, Sendable {
    // MARK: - Property
    let breakpoints: [Double]
    let moving: [TimeRange]

    // MARK: - Initializer
    init(
        breakpoints: [Double],
        moving: [TimeRange]
    ) {
        self.breakpoints = breakpoints
        self.moving = moving
    }

    // A keyframed property bends at every keyframe and moves between two keyframes of different values.
    init(keyframes: [Keyframe<Double>]) {
        let sorted = KeyframeTrack(keyframes: keyframes).keyframes
        let moving = zip(sorted, sorted.dropFirst())
            .filter { start, end in start.value != end.value }
            .map { start, end in TimeRange(start: start.at, end: end.at) }

        self.init(breakpoints: sorted.map(\.at), moving: moving)
    }

    // Ramps, each moving over its whole range and bending at both ends.
    init(ramps: [TimeRange]) {
        self.init(breakpoints: ramps.flatMap { [$0.start, $0.end] }, moving: ramps)
    }

    // MARK: - Public
    // The times on the clock `clock` maps clip time to.
    func mapped(through clock: TimeMap) -> EnvelopeTimes {
        EnvelopeTimes(
            breakpoints: breakpoints.map(clock.sequenceTime(ofClipTime:)),
            moving: moving.map { range in
                TimeRange(start: clock.sequenceTime(ofClipTime: range.start), end: clock.sequenceTime(ofClipTime: range.end))
            }
        )
    }

    func merged(with other: EnvelopeTimes) -> EnvelopeTimes {
        EnvelopeTimes(breakpoints: breakpoints + other.breakpoints, moving: moving + other.moving)
    }

    // The times of an envelope over `range`: both its ends, every breakpoint inside it, and every frame time k / fps
    // inside it where the value moves, in order and each once.
    func times(
        over range: TimeRange,
        fps: Double
    ) -> [Double] {
        let frames = moving.compactMap { $0.intersection(range) }.flatMap { span in
            stride(from: Int(ceil(span.start * fps)), through: Int(floor(span.end * fps)), by: 1).map { Double($0) / fps }
        }
        let inside = (breakpoints + frames).filter { range.start < $0 && $0 < range.end }

        return [range.start] + Set(inside).sorted() + [range.end]
    }

    // MARK: - Private
}
