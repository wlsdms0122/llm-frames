//
//  ClipSample.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// `ownScale` is the clip's own scale times its animation's, a clip placed by a corner pin and an adjustment having no
// scale of their own, and `lengthFactor` its scale factor, which its lengths and its masks' feather are drawn at; a
// parent's scale is in neither. A title animated by unit has its units' `schedule`, and `animation` is then the motion
// of the whole title, its loop.
struct ClipSample: Equatable, Sendable {
    // MARK: - Property
    let window: TimeRange
    let animation: MotionSample
    let schedule: UnitSchedule?
    let ownScale: Scale

    var lengthFactor: Double {
        ownScale.factor
    }

    // MARK: - Initializer
    init(
        clip: ResolvedClip,
        at time: SampleTime
    ) {
        let window = TimeRange(start: clip.start, end: clip.end)
        let schedule = clip.unitSchedule
        let animation = schedule.map { UnitSampler().title(of: clip.animation, schedule: $0, at: time) }
            ?? AnimationSampler().sample(of: clip.animation, in: window, at: time)

        self.window = window
        self.animation = animation
        self.schedule = schedule
        let scale: [Keyframe<Scale>]? = switch clip.content {
        case let .picture(_, .transform(transform), _):
            transform.scale

        case let .null(null):
            null.transform.scale

        case .picture(_, .cornerPin, _), .adjustment:
            nil
        }
        self.ownScale = (scale.map { $0.value(at: time) } ?? .identity).multiplied(by: animation.motion.value(of: .scale))
    }

    // MARK: - Public
    // MARK: - Private
}
