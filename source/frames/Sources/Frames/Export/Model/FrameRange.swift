//
//  FrameRange.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The times `--from`, `--to` and `--step` ask for, in seconds: from + k × step for every k whose time, measured to the
// microsecond, is before `to`. `from` defaults to 0 and `to` to the end of the media or sequence.
package struct FrameRange: Equatable, Sendable {
    // MARK: - Property
    package let from: Double?
    package let to: Double?
    package let step: Double

    // MARK: - Initializer
    package init(
        from: Double? = nil,
        to: Double? = nil,
        step: Double = 1
    ) {
        self.from = from
        self.to = to
        self.step = step
    }

    // MARK: - Public
    // The times over a `kind` (a video or a sequence) that runs over [0, end). Each time is from + k × step, not a
    // running sum, so no rounding builds up over a long range.
    func times(
        end: Double,
        kind: String
    ) throws -> [Double] {
        guard step.timeTicks > 0 else { throw ExportError.nonPositiveStep(step) }

        let start = from ?? 0
        let last = to ?? end
        guard start.timeTicks >= 0, start.timeTicks < end.timeTicks else {
            throw ExportError.timeOutside(option: "--from", time: start, end: end, kind: kind)
        }
        guard last.timeTicks <= end.timeTicks else { throw ExportError.endPastEnd(time: last, end: end, kind: kind) }
        guard start.timeTicks < last.timeTicks else { throw ExportError.emptyRange(from: start, to: last) }

        var times: [Double] = []
        while true {
            let time = start + Double(times.count) * step
            guard time.timeTicks < last.timeTicks else { break }

            times.append(time)
        }

        return times
    }

    // MARK: - Private
}
