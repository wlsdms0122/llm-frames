//
//  AnimationSampler.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// On a window shorter than the entrance and the exit, the entrance keeps its own pace and the exit plays whole in the
// time the entrance leaves.
struct AnimationSampler: Sendable {
    // MARK: - Property
    private let evaluator = SpanEvaluator()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func sample(
        of animation: ResolvedAnimation,
        in window: TimeRange,
        at time: Double
    ) -> MotionSample {
        guard window.contains(time) else { return .none }

        let entranceLength = min(animation.entrance?.length ?? 0, window.length)
        let exitLength = min(animation.exit?.length ?? 0, window.length - entranceLength)
        let loopStart = window.start + entranceLength
        let exitStart = window.end - exitLength

        if let entrance = animation.entrance, time < loopStart {
            return sample(of: entrance.span, at: (time - window.start) / entrance.length)
        }

        if let exit = animation.exit, exitLength > 0, time >= exitStart {
            return sample(of: exit.span, at: (time - exitStart) / exitLength)
        }

        if let loop = animation.loop {
            let elapsed = (time - loopStart).truncatingRemainder(dividingBy: loop.length)
            return sample(of: loop.span, at: elapsed / loop.length)
        }

        return .none
    }

    // MARK: - Private
    private func sample(
        of span: Span,
        at progress: Double
    ) -> MotionSample {
        MotionSample(motion: evaluator.motion(of: span, at: progress), revealFrom: span.revealFrom)
    }
}
