//
//  AnimationSampler.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// An animation at one instant of the visible window `[start, end)` it runs over. The entrance runs at its own length
// from the start, and the exit over the end, taking its `seconds` or what the entrance leaves, whichever is shorter,
// so on a short window the entrance runs first and the exit plays whole in the time that is left. The loop repeats
// every `period` from the end of the entrance to the start of the exit. Outside every span, and outside the window,
// every property is at its default.
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
