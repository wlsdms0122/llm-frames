//
//  SpanEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct SpanEvaluator: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func motion(
        of span: Span,
        at progress: Double
    ) -> Motion {
        let bent = span.ease.value(at: min(max(progress, 0), 1))
        let values = MotionProperty.allCases.reduce(into: [MotionProperty: Double]()) { values, property in
            values[property] = value(of: property, in: span, atBent: bent)
        }

        return Motion(values: values)
    }

    // MARK: - Private
    private func value(
        of property: MotionProperty,
        in span: Span,
        atBent bent: Double
    ) -> Double {
        let points = span.keys.enumerated()
            .compactMap { index, key in key.values[property].map { (index: index, t: key.t, value: $0) } }
            .sorted { $0.t == $1.t ? $0.index < $1.index : $0.t < $1.t }
            .map { (t: $0.t, value: $0.value) }
        guard let first = points.first, let last = points.last else { return property.defaultValue }

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
