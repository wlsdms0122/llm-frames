//
//  UnitSampler.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title's animation played by unit. Each unit takes the entrance and the exit on its own schedule, holding the
// entrance at progress 0 before its turn and the exit at progress 1 after it, and the whole title takes the loop
// while every unit rests.
struct UnitSampler: Sendable {
    // MARK: - Property
    private let evaluator = SpanEvaluator()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // The motion of the whole title: the loop over the schedule's rest, and none outside it.
    func title(
        of animation: ResolvedAnimation,
        schedule: UnitSchedule,
        at time: Double
    ) -> MotionSample {
        let rest = schedule.rest
        guard let loop = animation.loop, rest.contains(time) else { return .none }

        let elapsed = (time - rest.start).truncatingRemainder(dividingBy: loop.length)

        return sample(of: loop.span, at: elapsed / loop.length)
    }

    func unit(
        _ index: Int,
        of animation: ResolvedAnimation,
        schedule: UnitSchedule,
        at time: Double
    ) -> MotionSample {
        guard schedule.window.contains(time) else { return .none }

        if let entrance = animation.entrance, schedule.entrance > 0 {
            let start = schedule.entranceStart(of: index)
            if time < start + schedule.entrance {
                return sample(of: entrance.span, at: max(time - start, 0) / schedule.entrance)
            }
        }
        if let exit = animation.exit, schedule.exit > 0 {
            let start = schedule.exitStart(of: index)
            if time >= start {
                return sample(of: exit.span, at: min((time - start) / schedule.exit, 1))
            }
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
