//
//  PlayedRange.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a timed media clip that is not on the storyline plays, and how any sound plays: clip time `in` at sequence time
// `origin` along `map`, up to `out` in media time. Past `out` a looping clip repeats from `in` and any other holds the
// last frame before `out`. `origin` is the start of the clip's window before tracking narrowed it, so it can lie before
// the clip's `start`.
struct PlayedRange: Equatable, Sendable {
    // MARK: - Property
    let map: TimeMap
    let out: Double
    let loop: Bool

    var `in`: Double {
        map.in
    }

    var origin: Double {
        map.origin
    }

    var speed: Double {
        map.speed
    }

    // The sequence seconds from `in` to `out`: a single-start window's length, and the period of a loop.
    var naturalLength: Double {
        (out - map.in) / map.speed
    }

    // MARK: - Initializer
    init(
        map: TimeMap,
        out: Double,
        loop: Bool
    ) {
        self.map = map
        self.out = out
        self.loop = loop
    }

    // MARK: - Public
    // Past `out` a looping clip's clip time is wrapped on whole microseconds, so it lies in [in, out) at that
    // resolution.
    func clipTime(atSequenceTime time: Double) -> Double {
        let clipTime = map.clipTime(atSequenceTime: time)
        guard clipTime.timeTicks >= out.timeTicks else { return clipTime }
        guard loop else { return out - .timeResolution }

        let inTicks = map.in.timeTicks
        // A range shorter than a microsecond repeats `in` rather than dividing by zero.
        let period = max(out.timeTicks - inTicks, 1)

        return Double(timeTicks: inTicks + (clipTime.timeTicks - inTicks) % period)
    }

    // The same range starting at another sequence time.
    func starting(at origin: Double) -> PlayedRange {
        PlayedRange(map: TimeMap(origin: origin, in: map.in, speed: map.speed), out: out, loop: loop)
    }

    // MARK: - Private
}
