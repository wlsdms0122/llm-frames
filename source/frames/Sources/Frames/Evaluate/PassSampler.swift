//
//  PassSampler.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Reads an animation at an instant on T's side of the jumps written on its spans (FRAMES-29), T being the frame's
// instant. A pass's jumps are the end of a span eased by `step` and two keys of one property at one `t`, compared on
// the eased progress. Where the instant and T play in different passes, a handover or a loop seam lies between them,
// which is read as it is. The clamp runs along the way from T to the instant: each property takes the limit from T's
// side at the first jump it meets, a jump of T's pass up to the seam before one of the instant's pass from it.
struct PassSampler: Sendable {
    // MARK: - Property
    private let evaluator = SpanEvaluator()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `pass(at:)` gives the pass that plays at a time, nil where none does and the animation adds no motion.
    func sample(
        at time: Double,
        onSideOf frameTime: Double,
        pass: (Double) -> AnimationPass?
    ) -> MotionSample {
        let framePass = pass(frameTime)
        let instantPass = pass(time)
        if let framePass, framePass == instantPass {
            return sample(of: framePass, at: time, onSideOf: frameTime)
        }

        let fromSeam = sample(of: instantPass, at: time, onSideOf: frameTime, after: framePass)
        guard let framePass else { return fromSeam }

        let frameProgress = framePass.progress(at: frameTime)
        let progress = framePass.progress(at: time)
        let held = Set(MotionProperty.allCases.filter { property in
            evaluator.hasJump(of: property, in: framePass.span, between: frameProgress, and: progress)
        })
        guard !held.isEmpty else { return fromSeam }

        let upToSeam = sample(of: framePass, at: time, onSideOf: frameTime)
        let values = MotionProperty.allCases.reduce(into: [MotionProperty: Double]()) { values, property in
            values[property] = held.contains(property) ? upToSeam.motion.values[property] : fromSeam.motion.values[property]
        }

        return MotionSample(
            motion: Motion(values: values),
            revealFrom: held.contains(.reveal) ? upToSeam.revealFrom : fromSeam.revealFrom
        )
    }

    // MARK: - Private
    private func sample(
        of pass: AnimationPass,
        at time: Double,
        onSideOf frameTime: Double
    ) -> MotionSample {
        MotionSample(
            motion: evaluator.motion(of: pass.span, at: pass.progress(at: time), onSideOf: pass.progress(at: frameTime)),
            revealFrom: pass.span.revealFrom
        )
    }

    // The instant's pass from the seam on. When T lies past its end, a `step` end there is the first jump met from the
    // seam, and its limit from T's side is what plays from that end on: T's pass at its start, or none.
    private func sample(
        of instantPass: AnimationPass?,
        at time: Double,
        onSideOf frameTime: Double,
        after framePass: AnimationPass?
    ) -> MotionSample {
        guard let instantPass else { return .none }

        let isStepEndBetween = instantPass.span.ease == .step
            && instantPass.progress(at: time) < 1
            && instantPass.progress(at: frameTime) >= 1
        guard isStepEndBetween else { return sample(of: instantPass, at: time, onSideOf: frameTime) }

        return framePass.map { sample(of: $0, at: $0.start, onSideOf: $0.start) } ?? .none
    }
}
