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
    private let passes = PassSampler()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func sample(
        of animation: ResolvedAnimation,
        in window: TimeRange,
        at time: Double
    ) -> MotionSample {
        guard window.contains(time) else { return .none }
        // A sample of a frame with motion blur reads on T's side of the jumps.
        guard SampleInstant.current == nil else {
            return sample(of: animation, in: window, at: time, onSideOf: SampleInstant.side(at: time))
        }

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

    // The sample at an instant on T's side, T being the frame's instant and the window's ends being jumps (FRAMES-29):
    // none where T lies outside the window, and otherwise the instant held inside it, so the clip stands at its first
    // pose before its window and at its last after it.
    func sample(
        of animation: ResolvedAnimation,
        in window: TimeRange,
        at time: Double,
        onSideOf frameTime: Double
    ) -> MotionSample {
        guard window.contains(frameTime) else { return .none }

        let instant = window.held(time)

        return passes.sample(
            at: instant,
            onSideOf: frameTime,
            passes: passes(of: animation, in: window, between: min(instant, frameTime), and: max(instant, frameTime))
        )
    }

    // MARK: - Private
    private func sample(
        of span: Span,
        at progress: Double
    ) -> MotionSample {
        MotionSample(motion: evaluator.motion(of: span, at: progress), revealFrom: span.revealFrom)
    }

    // The entrance from the window start, the loop's periods after it, and the exit to the window's end, each that
    // plays at some time from `lower` to `upper`, in time order.
    private func passes(
        of animation: ResolvedAnimation,
        in window: TimeRange,
        between lower: Double,
        and upper: Double
    ) -> [AnimationPass] {
        let entranceLength = min(animation.entrance?.length ?? 0, window.length)
        let exitLength = min(animation.exit?.length ?? 0, window.length - entranceLength)
        let loopStart = window.start + entranceLength
        let exitStart = window.end - exitLength
        var passes = [AnimationPass]()

        if let entrance = animation.entrance, entranceLength > 0, lower < loopStart {
            passes.append(AnimationPass(
                span: entrance.span,
                start: window.start,
                length: entrance.length,
                plays: TimeRange(start: window.start, end: loopStart)
            ))
        }

        if let loop = animation.loop {
            passes += AnimationPass.periods(
                of: loop.span,
                length: loop.length,
                from: loopStart,
                until: exitStart,
                between: lower,
                and: upper
            )
        }

        if let exit = animation.exit, exitLength > 0, exitStart <= upper {
            passes.append(AnimationPass(
                span: exit.span,
                start: exitStart,
                length: exitLength,
                plays: TimeRange(start: exitStart, end: window.end)
            ))
        }

        return passes
    }
}
