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
        at sample: SampleInstant
    ) -> Double {
        guard let transition = storyline[index].transition else { return 0 }

        let time = storyline.valueTime(ofEntry: index, in: sample)
        return progress(through: TimeRange(start: transition.start, end: transition.end), at: time.instant)
    }

    // The motion at a time outside a sample of a frame with motion blur.
    func motion(
        of index: Int,
        in storyline: [ResolvedStorylineClip],
        at time: Double
    ) -> MotionSample {
        motion(of: index, in: storyline, at: SampleInstant(frameTime: time))
    }

    // Which transition the entry takes part in is decided at T. Out of the entry's drawn range this holds the motion at
    // the range's edge.
    func motion(
        of index: Int,
        in storyline: [ResolvedStorylineClip],
        at sample: SampleInstant
    ) -> MotionSample {
        let time = sample.frameTime
        if let incoming = storyline[index].transition, time < incoming.end {
            return self.sample(of: incoming.incoming, through: incoming, broughtBy: index, in: storyline, at: sample)
        }
        if storyline.indices.contains(index + 1), let outgoing = storyline[index + 1].transition, time >= outgoing.start {
            return self.sample(of: outgoing.outgoing, through: outgoing, broughtBy: index + 1, in: storyline, at: sample)
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
        at sample: SampleInstant
    ) -> MotionSample {
        guard let span else { return .none }

        let range = TimeRange(start: transition.start, end: transition.end)
        let frameProgress = progress(through: range, at: sample.frameTime)
        let progress = progress(broughtBy: index, in: storyline, at: sample)

        return MotionSample(
            motion: evaluator.motion(of: span, at: progress, onSideOf: frameProgress),
            revealFrom: span.revealFrom
        )
    }
}
