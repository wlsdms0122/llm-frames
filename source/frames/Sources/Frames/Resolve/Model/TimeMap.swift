//
//  TimeMap.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The straight line from a clip's clock to sequence time: clip time `in` sits at sequence time `origin`, and clip time
// runs `speed` times as fast. The line goes on outside the clip, which is where handles and early keyframes lie.
struct TimeMap: Equatable, Sendable {
    // MARK: - Property
    static let sequence = TimeMap(origin: 0, in: 0, speed: 1)

    let origin: Double
    let `in`: Double
    let speed: Double

    // MARK: - Initializer
    init(
        origin: Double,
        in: Double,
        speed: Double
    ) {
        self.origin = origin
        self.in = `in`
        self.speed = speed
    }

    // MARK: - Public
    func sequenceTime(ofClipTime time: Double) -> Double {
        origin + (time - `in`) / speed
    }

    func clipTime(atSequenceTime time: Double) -> Double {
        `in` + (time - origin) * speed
    }

    // The clip time of a clip that plays from `in` up to `out`. Past `out` a looping clip repeats from `in`, wrapped
    // on whole microseconds so the time lies in [in, out) at that resolution, and any other holds the last frame
    // before `out`.
    func clipTime(
        atSequenceTime time: Double,
        out: Double,
        loop: Bool
    ) -> Double {
        let clipTime = clipTime(atSequenceTime: time)
        guard hasReached(out, at: clipTime) else { return clipTime }
        guard loop else { return out - .timeResolution }

        let inTicks = `in`.timeTicks
        // A range shorter than a microsecond repeats `in` rather than dividing by zero.
        let period = max(out.timeTicks - inTicks, 1)

        return Double(timeTicks: inTicks + (clipTime.timeTicks - inTicks) % period)
    }

    // Whether a clip that plays up to `out` and does not loop has ended at a sequence time.
    func hasEnded(
        atSequenceTime time: Double,
        out: Double,
        loop: Bool
    ) -> Bool {
        !loop && hasReached(out, at: clipTime(atSequenceTime: time))
    }

    // MARK: - Private
    private func hasReached(
        _ out: Double,
        at clipTime: Double
    ) -> Bool {
        clipTime.timeTicks >= out.timeTicks
    }
}
