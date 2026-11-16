//
//  TransitionSampler.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A transition at one instant. Its progress runs in a straight line from 0 at its start to 1 at its end, and each of
// its incoming, outgoing, cover and matte bends that progress by its own ease.
struct TransitionSampler: Sendable {
    // MARK: - Property
    private let evaluator = SpanEvaluator()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // Held at 0 before the transition and at 1 after it.
    func progress(
        through range: TimeRange,
        at time: Double
    ) -> Double {
        min(max((time - range.start) / range.length, 0), 1)
    }

    // An incoming or outgoing unit moved by its span, or still when the transition gives it none.
    func unit(
        moving span: Span?,
        in content: Rectangle,
        at progress: Double
    ) -> UnitPresentation {
        let sample = span.map { span in
            MotionSample(motion: evaluator.motion(of: span, at: progress), revealFrom: span.revealFrom)
        }

        return UnitPresentation(sample: sample ?? .none, content: content)
    }

    // A cover's keys take only opacity.
    func coverOpacity(
        of span: Span,
        at progress: Double
    ) -> Double {
        evaluator.motion(of: span, at: progress).value(of: .opacity)
    }

    // The luminance below which a matte shows the incoming unit.
    func matteProgress(
        easedBy ease: Ease,
        at progress: Double
    ) -> Double {
        ease.value(at: progress)
    }

    // MARK: - Private
}
