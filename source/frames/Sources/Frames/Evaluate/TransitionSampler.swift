//
//  TransitionSampler.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Each of a transition's incoming, outgoing, cover and matte bends the linear progress by its own ease. A transition's
// progress belongs to the storyline clip that brings it in, so under motion blur it is read at that clip's value time
// on T's side, whichever side it moves (FRAMES-29), while which transition an entry takes part in is decided at T.
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

    // The progress of the transition the entry at `index` brings in, at that entry's value time.
    func progress(
        broughtBy index: Int,
        in storyline: [ResolvedStorylineClip],
        at time: Double
    ) -> Double {
        guard let transition = storyline[index].transition else { return 0 }

        let valueTime = SampleInstant.valueTime(
            ownedBy: storyline[index].isMotionBlurred,
            in: drawnRange(of: index, in: storyline),
            at: time
        )
        return progress(through: TimeRange(start: transition.start, end: transition.end), at: valueTime)
    }

    // The range an entry draws in: its edit range, widened by the transitions at its two ends.
    func drawnRange(
        of index: Int,
        in storyline: [ResolvedStorylineClip]
    ) -> TimeRange {
        let entry = storyline[index]
        let outgoing = storyline.indices.contains(index + 1) ? storyline[index + 1].transition : nil

        return TimeRange(
            start: min(entry.start, entry.transition?.start ?? entry.start),
            end: max(entry.end, outgoing?.end ?? entry.end)
        )
    }

    // Out of the entry's drawn range this holds the motion at the range's edge.
    func motion(
        of index: Int,
        in storyline: [ResolvedStorylineClip],
        at time: Double
    ) -> MotionSample {
        if let incoming = storyline[index].transition, time < incoming.end {
            return sample(of: incoming.incoming, through: incoming, broughtBy: index, in: storyline, at: time)
        }
        if storyline.indices.contains(index + 1), let outgoing = storyline[index + 1].transition, time >= outgoing.start {
            return sample(of: outgoing.outgoing, through: outgoing, broughtBy: index + 1, in: storyline, at: time)
        }

        return .none
    }

    // A cover's keys take only opacity.
    func coverOpacity(
        of span: Span,
        at progress: Double
    ) -> Double {
        coverOpacity(of: span, at: progress, onSideOf: progress)
    }

    // `frameProgress` is the transition's progress at T.
    func coverOpacity(
        of span: Span,
        at progress: Double,
        onSideOf frameProgress: Double
    ) -> Double {
        evaluator.motion(of: span, at: progress, onSideOf: frameProgress).value(of: .opacity)
    }

    // The luminance below which a matte shows the incoming storyline picture.
    func matteProgress(
        easedBy ease: Ease,
        at progress: Double
    ) -> Double {
        matteProgress(easedBy: ease, at: progress, onSideOf: progress)
    }

    // A `step` ease holds T's side of its end.
    func matteProgress(
        easedBy ease: Ease,
        at progress: Double,
        onSideOf frameProgress: Double
    ) -> Double {
        let isStepEnd = ease == .step && (frameProgress < 1) != (progress < 1)

        return ease.value(at: isStepEnd ? frameProgress : progress)
    }

    // MARK: - Private
    private func sample(
        of span: Span?,
        through transition: ResolvedTransition,
        broughtBy index: Int,
        in storyline: [ResolvedStorylineClip],
        at time: Double
    ) -> MotionSample {
        guard let span else { return .none }

        let range = TimeRange(start: transition.start, end: transition.end)
        let frameProgress = progress(through: range, at: SampleInstant.current?.frameTime ?? time)
        let progress = progress(broughtBy: index, in: storyline, at: time)

        return MotionSample(
            motion: evaluator.motion(of: span, at: progress, onSideOf: frameProgress),
            revealFrom: span.revealFrom
        )
    }
}
