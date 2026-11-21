//
//  PassSampler.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Reads an animation at an instant on T's side of the jumps written on its spans (FRAMES-29), T being the frame's
// instant. A pass's jumps are the end of a span eased by `step` and two keys of one property at one `t`, compared on
// the eased progress. Between passes lies a handover or a loop seam, which is read as it is. The clamp runs along the
// way from T to the instant through every pass on it: each property takes the limit from T's side at the first jump
// it meets, in the part of each pass the way crosses.
struct PassSampler: Sendable {
    // MARK: - Property
    private let evaluator = SpanEvaluator()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `passes` are the passes that play at some time between T and the instant, in time order. Where none plays, the
    // animation adds no motion.
    func sample(
        at time: Double,
        onSideOf frameTime: Double,
        passes: [AnimationPass]
    ) -> MotionSample {
        let isForward = time >= frameTime
        let way = isForward ? passes : passes.reversed()
        let crossings = way.map { crossing(of: $0, at: time, onSideOf: frameTime, isForward: isForward) }
        let instantPass = passes.last { $0.plays.contains(time) }

        let samples = MotionProperty.allCases.reduce(into: [MotionProperty: MotionSample]()) { samples, property in
            let index = crossings.firstIndex { crossing in
                evaluator.hasJump(of: property, in: crossing.pass.span, between: crossing.entry, and: crossing.exit)
            }
            samples[property] = if let index {
                limit(at: index, of: crossings, isForward: isForward)
            } else {
                instantPass.map { sample(of: $0, at: $0.progress(at: time)) } ?? MotionSample.none
            }
        }

        return MotionSample(
            motion: Motion(values: samples.reduce(into: [:]) { values, pair in
                values[pair.key] = pair.value.motion.values[pair.key]
            }),
            revealFrom: samples[.reveal]?.revealFrom ?? MotionSample.none.revealFrom
        )
    }

    // MARK: - Private
    // The progress a pass is entered and left at on the way. A pass that holds T is entered at T's progress and one
    // that holds the instant left at the instant's. A pass the way crosses whole is read on past its ends, which the
    // ease clamps to 0 and 1, so a jump at its end counts, and a pass cut by the next is crossed up to the cut.
    private func crossing(
        of pass: AnimationPass,
        at time: Double,
        onSideOf frameTime: Double,
        isForward: Bool
    ) -> (pass: AnimationPass, entry: Double, exit: Double) {
        let cut = pass.isCut ? pass.progress(at: pass.plays.end) : nil
        let entry = isForward || pass.plays.contains(frameTime) ? nil : cut
        let exit = isForward && !pass.plays.contains(time) ? cut : nil

        return (pass, entry ?? pass.progress(at: frameTime), exit ?? pass.progress(at: time))
    }

    // The limit from T's side at the first jump in the crossing at `index`. Back from T, a `step` end is the end of
    // the pass, and its limit from T's side is what plays from that end on: the pass after it at its start, or none
    // where no pass follows at once.
    private func limit(
        at index: Int,
        of crossings: [(pass: AnimationPass, entry: Double, exit: Double)],
        isForward: Bool
    ) -> MotionSample {
        let crossing = crossings[index]
        let isStepEndBehind = !isForward
            && crossing.pass.span.ease == .step
            && crossing.entry >= 1
            && crossing.exit < 1
        guard isStepEndBehind else {
            return MotionSample(
                motion: evaluator.motion(of: crossing.pass.span, at: crossing.exit, onSideOf: crossing.entry),
                revealFrom: crossing.pass.span.revealFrom
            )
        }

        guard index > 0 else { return .none }

        let next = crossings[index - 1].pass
        guard next.plays.start.timeTicks <= crossing.pass.plays.end.timeTicks else { return .none }

        return sample(of: next, at: next.progress(at: next.plays.start))
    }

    private func sample(
        of pass: AnimationPass,
        at progress: Double
    ) -> MotionSample {
        MotionSample(motion: evaluator.motion(of: pass.span, at: progress), revealFrom: pass.span.revealFrom)
    }
}
