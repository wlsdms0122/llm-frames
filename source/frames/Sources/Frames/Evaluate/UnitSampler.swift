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
    private let passes = PassSampler()

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

    // The title's motion and a unit's at an instant on T's side, T being the frame's instant (FRAMES-29): none where T
    // lies outside the schedule's window, and otherwise the instant held inside it.
    func title(
        of animation: ResolvedAnimation,
        schedule: UnitSchedule,
        at time: Double,
        onSideOf frameTime: Double
    ) -> MotionSample {
        guard schedule.window.contains(frameTime) else { return .none }

        return passes.sample(at: schedule.window.held(time), onSideOf: frameTime) { time in
            titlePass(of: animation, schedule: schedule, at: time)
        }
    }

    func unit(
        _ index: Int,
        of animation: ResolvedAnimation,
        schedule: UnitSchedule,
        at time: Double,
        onSideOf frameTime: Double
    ) -> MotionSample {
        guard schedule.window.contains(frameTime) else { return .none }

        return passes.sample(at: schedule.window.held(time), onSideOf: frameTime) { time in
            unitPass(index, of: animation, schedule: schedule, at: time)
        }
    }

    // MARK: - Private
    // The loop's period over the schedule's rest that holds the time.
    private func titlePass(
        of animation: ResolvedAnimation,
        schedule: UnitSchedule,
        at time: Double
    ) -> AnimationPass? {
        let rest = schedule.rest
        guard let loop = animation.loop, rest.contains(time) else { return nil }

        let period = ((time - rest.start) / loop.length).rounded(.down)
        return AnimationPass(span: loop.span, start: rest.start + period * loop.length, length: loop.length)
    }

    // A unit's entrance up to its end, held at progress 0 before the unit's turn, and its exit from its start.
    private func unitPass(
        _ index: Int,
        of animation: ResolvedAnimation,
        schedule: UnitSchedule,
        at time: Double
    ) -> AnimationPass? {
        if let entrance = animation.entrance, schedule.entrance > 0 {
            let start = schedule.entranceStart(of: index)
            if time < start + schedule.entrance {
                return AnimationPass(span: entrance.span, start: start, length: schedule.entrance)
            }
        }
        if let exit = animation.exit, schedule.exit > 0 {
            let start = schedule.exitStart(of: index)
            if time >= start {
                return AnimationPass(span: exit.span, start: start, length: schedule.exit)
            }
        }

        return nil
    }

    private func sample(
        of span: Span,
        at progress: Double
    ) -> MotionSample {
        MotionSample(motion: evaluator.motion(of: span, at: progress), revealFrom: span.revealFrom)
    }
}
