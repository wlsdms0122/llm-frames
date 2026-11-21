//
//  AnimationPass.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// One play of an animation's span: its entrance, one period of its loop, or its exit. Its progress is 0 at `start` and
// 1 at `start + length`, and it plays over `plays`, which ends before that where the next pass takes over.
struct AnimationPass: Equatable, Sendable {
    // MARK: - Property
    let span: Span
    let start: Double
    let length: Double
    let plays: TimeRange

    var end: Double {
        start + length
    }

    // Whether the next pass takes over before the span reaches its end, compared on the microsecond as times are.
    var isCut: Bool {
        plays.end.timeTicks < end.timeTicks
    }

    // MARK: - Initializer
    init(
        span: Span,
        start: Double,
        length: Double,
        plays: TimeRange
    ) {
        self.span = span
        self.start = start
        self.length = length
        self.plays = plays
    }

    // MARK: - Public
    // The periods of a loop that plays from `start` until `end` and that play at some time from `lower` to `upper`,
    // in time order.
    static func periods(
        of span: Span,
        length: Double,
        from start: Double,
        until end: Double,
        between lower: Double,
        and upper: Double
    ) -> [AnimationPass] {
        guard start < end, length > 0 else { return [] }

        let first = max(Int(((lower - start) / length).rounded(.down)) - 1, 0)
        let last = Int(((upper - start) / length).rounded(.down)) + 1
        guard first <= last else { return [] }

        return (first ... last).compactMap { period in
            let periodStart = start + Double(period) * length
            let periodEnd = min(start + Double(period + 1) * length, end)
            guard periodStart < periodEnd, periodStart <= upper, lower < periodEnd else { return nil }

            return AnimationPass(
                span: span,
                start: periodStart,
                length: length,
                plays: TimeRange(start: periodStart, end: periodEnd)
            )
        }
    }

    func progress(at time: Double) -> Double {
        (time - start) / length
    }

    // MARK: - Private
}
