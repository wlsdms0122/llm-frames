//
//  ClipSample.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// `ownScale` is the clip's own scale times its animation's, and `lengthFactor` its scale factor, which its lengths and
// its masks' feather are drawn at; a parent's scale is in neither.
struct ClipSample: Equatable, Sendable {
    // MARK: - Property
    let window: TimeRange
    let animation: MotionSample
    let opacity: Double
    let blend: String
    let ownScale: Scale

    var lengthFactor: Double {
        ownScale.factor
    }

    // MARK: - Initializer
    init(
        clip: ResolvedClip,
        at time: Double
    ) {
        let window = TimeRange(start: clip.start, end: clip.end)
        let animation = AnimationSampler().sample(of: clip.animation, in: window, at: time)

        self.window = window
        self.animation = animation
        self.opacity = clip.opacity.opacity(at: time)
        self.blend = clip.blend
        self.ownScale = (clip.scale.map { $0.value(at: time) } ?? .identity).multiplied(by: animation.motion.value(of: .scale))
    }

    // MARK: - Public
    // MARK: - Private
}
