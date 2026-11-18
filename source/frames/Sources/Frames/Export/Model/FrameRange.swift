//
//  FrameRange.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The times `--from`, `--to` and `--step` ask for, in seconds: from + k × step for every k whose time, measured to the
// microsecond, is before `to`. `from` defaults to 0 and `to` to the end of the media or sequence. It holds the rule for
// every command that reads a range, `ocr` as well as `sheet` and `extract`, and each checks it with its own messages.
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
    // The first time, 0 when `from` is not given.
    var start: Double {
        from ?? 0
    }

    // The time the range stops before, the end of the media or sequence when `to` is not given.
    func last(end: Double) -> Double {
        to ?? end
    }

    // The times over a `kind` (a video or a sequence) that runs over [0, end), once the range is checked against it.
    func times(
        end: Double,
        kind: String
    ) throws -> [Double] {
        guard step >= 0.000_001 else { throw ExportError.nonPositiveStep(step) }

        let last = last(end: end)
        try FrameSpan(end: end, kind: kind).check(start, option: "--from")
        guard last.timeTicks <= end.timeTicks else { throw ExportError.endPastEnd(time: last, end: end, kind: kind) }
        guard start.timeTicks < last.timeTicks else { throw ExportError.emptyRange(from: start, to: last) }

        return times(before: last)
    }

    // from + k × step for every k whose time, measured to the microsecond, is before `last`. Each time is from + k ×
    // step, not a running sum, so no rounding builds up over a long range. A step under a microsecond never reaches
    // `last`, so it gives no time; every caller stops on it first with its own message.
    func times(before last: Double) -> [Double] {
        guard step.timeTicks > 0 else { return [] }

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
