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

        return passes.sample(at: window.held(time), onSideOf: frameTime) { pass(of: animation, in: window, at: $0) }
    }

    // MARK: - Private
    private func sample(
        of span: Span,
        at progress: Double
    ) -> MotionSample {
        MotionSample(motion: evaluator.motion(of: span, at: progress), revealFrom: span.revealFrom)
    }

    // The entrance from the window start, the exit to its end, and the loop's period between them that holds the time.
    private func pass(
        of animation: ResolvedAnimation,
        in window: TimeRange,
        at time: Double
    ) -> AnimationPass? {
        let entranceLength = min(animation.entrance?.length ?? 0, window.length)
        let exitLength = min(animation.exit?.length ?? 0, window.length - entranceLength)
        let loopStart = window.start + entranceLength
        let exitStart = window.end - exitLength

        if let entrance = animation.entrance, time < loopStart {
            return AnimationPass(span: entrance.span, start: window.start, length: entrance.length)
        }

        if let exit = animation.exit, exitLength > 0, time >= exitStart {
            return AnimationPass(span: exit.span, start: exitStart, length: exitLength)
        }

        if let loop = animation.loop {
            let period = ((time - loopStart) / loop.length).rounded(.down)
            return AnimationPass(span: loop.span, start: loopStart + period * loop.length, length: loop.length)
        }

        return nil
    }
}
