//
//  TransitionSampler.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Each of a transition's incoming, outgoing, cover and matte bends the linear progress by its own ease.
struct TransitionSampler: Sendable {
    // MARK: - Property
    private let evaluator = SpanEvaluator()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func progress(
        through range: TimeRange,
        at time: Double
    ) -> Double {
        min(max((time - range.start) / range.length, 0), 1)
    }

    // Out of the entry's drawn range this holds the motion at the range's edge.
    func motion(
        of index: Int,
        in storyline: [ResolvedStorylineClip],
        at time: Double
    ) -> MotionSample {
        if let incoming = storyline[index].transition, time < incoming.end {
            return sample(of: incoming.incoming, through: incoming, at: time)
        }
        if storyline.indices.contains(index + 1), let outgoing = storyline[index + 1].transition, time >= outgoing.start {
            return sample(of: outgoing.outgoing, through: outgoing, at: time)
        }

        return .none
    }

    // A cover's keys take only opacity.
    func coverOpacity(
        of span: Span,
        at progress: Double
    ) -> Double {
        evaluator.motion(of: span, at: progress).value(of: .opacity)
    }

    // The luminance below which a matte shows the incoming storyline picture.
    func matteProgress(
        easedBy ease: Ease,
        at progress: Double
    ) -> Double {
        ease.value(at: progress)
    }

    // MARK: - Private
    private func sample(
        of span: Span?,
        through transition: ResolvedTransition,
        at time: Double
    ) -> MotionSample {
        guard let span else { return .none }

        let progress = progress(through: TimeRange(start: transition.start, end: transition.end), at: time)
        return MotionSample(motion: evaluator.motion(of: span, at: progress), revealFrom: span.revealFrom)
    }
}
