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
        guard SampleInstant.current == nil else {
            return title(of: animation, schedule: schedule, at: time, onSideOf: SampleInstant.side(at: time))
        }

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
        guard SampleInstant.current == nil else {
            return unit(index, of: animation, schedule: schedule, at: time, onSideOf: SampleInstant.side(at: time))
        }

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

        let instant = schedule.window.held(time)
        let between = titlePasses(
            of: animation,
            schedule: schedule,
            between: min(instant, frameTime),
            and: max(instant, frameTime)
        )

        return passes.sample(at: instant, onSideOf: frameTime, passes: between)
    }

    func unit(
        _ index: Int,
        of animation: ResolvedAnimation,
        schedule: UnitSchedule,
        at time: Double,
        onSideOf frameTime: Double
    ) -> MotionSample {
        guard schedule.window.contains(frameTime) else { return .none }

        let instant = schedule.window.held(time)
        let between = unitPasses(
            index,
            of: animation,
            schedule: schedule,
            between: min(instant, frameTime),
            and: max(instant, frameTime)
        )

        return passes.sample(at: instant, onSideOf: frameTime, passes: between)
    }

    // MARK: - Private
    // The loop's periods over the schedule's rest that play at some time from `lower` to `upper`, in time order.
    private func titlePasses(
        of animation: ResolvedAnimation,
        schedule: UnitSchedule,
        between lower: Double,
        and upper: Double
    ) -> [AnimationPass] {
        guard let loop = animation.loop else { return [] }

        let rest = schedule.rest

        return AnimationPass.periods(
            of: loop.span,
            length: loop.length,
            from: rest.start,
            until: rest.end,
            between: lower,
            and: upper
        )
    }

    // A unit's entrance up to its end, held at progress 0 before the unit's turn from the window's start, and its exit
    // from its start to the window's end, each that plays at some time from `lower` to `upper`, in time order.
    private func unitPasses(
        _ index: Int,
        of animation: ResolvedAnimation,
        schedule: UnitSchedule,
        between lower: Double,
        and upper: Double
    ) -> [AnimationPass] {
        var passes = [AnimationPass]()
        var exitFrom = schedule.window.start

        if let entrance = animation.entrance, schedule.entrance > 0 {
            let start = schedule.entranceStart(of: index)
            exitFrom = start + schedule.entrance
            if lower < exitFrom {
                passes.append(AnimationPass(
                    span: entrance.span,
                    start: start,
                    length: schedule.entrance,
                    plays: TimeRange(start: schedule.window.start, end: exitFrom)
                ))
            }
        }

        if let exit = animation.exit, schedule.exit > 0 {
            let start = schedule.exitStart(of: index)
            let plays = TimeRange(start: max(start, exitFrom), end: schedule.window.end)
            if plays.start < plays.end, plays.start <= upper {
                passes.append(AnimationPass(span: exit.span, start: start, length: schedule.exit, plays: plays))
            }
        }

        return passes
    }

    private func sample(
        of span: Span,
        at progress: Double
    ) -> MotionSample {
        MotionSample(motion: evaluator.motion(of: span, at: progress), revealFrom: span.revealFrom)
    }
}
