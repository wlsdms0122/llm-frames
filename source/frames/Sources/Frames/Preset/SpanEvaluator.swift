//
//  SpanEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A span bends its progress once by its ease and reads each property on the bent progress. A reading at an instant on
// T's side, T being the frame's instant, is clamped to T's side of the span's jumps (FRAMES-29): its end under `step`,
// and two keys of one property at one `t`, compared on the bent progress, so an ease that overshoots is clamped only
// while its bent progress lies past `t` from T's.
struct SpanEvaluator: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func motion(
        of span: Span,
        at progress: Double
    ) -> Motion {
        motion(of: span, at: progress, onSideOf: progress)
    }

    func motion(
        of span: Span,
        at progress: Double,
        onSideOf frameProgress: Double
    ) -> Motion {
        let frameBent = span.ease.value(at: frameProgress)
        // T's side of a `step` end is T's own bent progress, 0 before it and 1 from it.
        let bent = isStepEnd(of: span, between: frameProgress, and: progress) ? frameBent : span.ease.value(at: progress)
        let values = MotionProperty.allCases.reduce(into: [MotionProperty: Double]()) { values, property in
            let points = self.points(of: property, in: span)
            values[property] = if let jump = jump(in: points, between: frameBent, and: bent) {
                bent > frameBent ? jump.value : value(in: points, atBent: jump.t, default: property.defaultValue)
            } else {
                value(in: points, atBent: bent, default: property.defaultValue)
            }
        }

        return Motion(values: values)
    }

    // Whether a jump written on the property lies between T's progress and the instant's: the span's end under `step`,
    // which every property takes, or two keys of the property at one `t`.
    func hasJump(
        of property: MotionProperty,
        in span: Span,
        between frameProgress: Double,
        and progress: Double
    ) -> Bool {
        guard !isStepEnd(of: span, between: frameProgress, and: progress) else { return true }

        let frameBent = span.ease.value(at: frameProgress)
        let bent = span.ease.value(at: progress)

        return jump(in: points(of: property, in: span), between: frameBent, and: bent) != nil
    }

    // MARK: - Private
    // A `step` span ends at progress 1, which T's side takes from.
    private func isStepEnd(
        of span: Span,
        between frameProgress: Double,
        and progress: Double
    ) -> Bool {
        span.ease == .step && (frameProgress < 1) != (progress < 1)
    }

    // The keys that name the property, in `t` order and in key order at one `t`.
    private func points(
        of property: MotionProperty,
        in span: Span
    ) -> [(t: Double, value: Double)] {
        let keyed: [(index: Int, t: Double, value: Double)] = span.keys.enumerated()
            .compactMap { index, key in key.values[property].map { (index: index, t: key.t, value: $0) } }

        return keyed
            .sorted { $0.t == $1.t ? $0.index < $1.index : $0.t < $1.t }
            .map { (t: $0.t, value: $0.value) }
    }

    // The first of two keys at one `t` nearest T's bent progress whose `t` lies between it and the instant's, a `t`
    // the instant's bent progress reaches counted: after T's from below, at or before T's from above, since T reads the
    // second key at `t`. The line that reaches `t` from below ends on the first key.
    private func jump(
        in points: [(t: Double, value: Double)],
        between frameBent: Double,
        and bent: Double
    ) -> (t: Double, value: Double)? {
        let jumps = zip(points, points.dropFirst()).filter { $0.t == $1.t }.map(\.0)

        return bent > frameBent
            ? jumps.first { frameBent < $0.t && $0.t <= bent }
            : jumps.last { bent < $0.t && $0.t <= frameBent }
    }

    private func value(
        in points: [(t: Double, value: Double)],
        atBent bent: Double,
        default defaultValue: Double
    ) -> Double {
        guard let first = points.first, let last = points.last else { return defaultValue }

        // An ease that overshoots carries the line through a key at 0 or 1 on past it, so a back-out still bounces.
        if bent < first.t {
            guard first.t == 0, let next = points.first(where: { $0.t > first.t }) else { return first.value }

            return line(from: first, to: next, at: bent)
        }

        if bent >= last.t {
            guard last.t == 1, bent > 1, let previous = points.last(where: { $0.t < last.t }) else { return last.value }

            return line(from: previous, to: last, at: bent)
        }

        guard let index = points.lastIndex(where: { $0.t <= bent }) else { return first.value }

        return line(from: points[index], to: points[index + 1], at: bent)
    }

    private func line(
        from start: (t: Double, value: Double),
        to end: (t: Double, value: Double),
        at bent: Double
    ) -> Double {
        .interpolate(from: start.value, to: end.value, progress: (bent - start.t) / (end.t - start.t))
    }
}
