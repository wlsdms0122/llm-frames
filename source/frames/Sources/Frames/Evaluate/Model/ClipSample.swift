//
//  ClipSample.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What every clip takes at one instant before it draws: its visible window, its animation at the instant over that
// window, its keyframed opacity, its blend mode, `normal` for an adjustment, which takes none, and its own scale times
// its animation's, which its lengths and its masks' feather are drawn at and a parent's scale is not (FRAMES-10).
struct ClipSample: Equatable, Sendable {
    // MARK: - Property
    let window: TimeRange
    let animation: MotionSample
    let opacity: Double
    let blend: String
    let ownScale: Double

    // MARK: - Initializer
    init(
        clip: ResolvedClip,
        at time: Double
    ) {
        let window = TimeRange(start: clip.start, end: clip.end)
        let animation = AnimationSampler().sample(of: clip.animation, in: window, at: time)

        self.window = window
        self.animation = animation
        self.opacity = clip.opacity.value(at: time)
        self.blend = clip.blend ?? "normal"
        self.ownScale = (clip.scale.map { $0.value(at: time) } ?? 1) * animation.motion.value(of: .scale)
    }

    // MARK: - Public
    // MARK: - Private
}
