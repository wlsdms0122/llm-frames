//
//  ClipSample.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What every clip takes at one instant before it draws: its visible window, its animation at the instant over that
// window, its keyframed opacity, and its blend mode, `normal` for an adjustment, which takes none.
struct ClipSample: Equatable, Sendable {
    // MARK: - Property
    let window: TimeRange
    let animation: MotionSample
    let opacity: Double
    let blend: String

    // MARK: - Initializer
    init(
        clip: ResolvedClip,
        at time: Double
    ) {
        let window = TimeRange(start: clip.start, end: clip.end)

        self.window = window
        self.animation = AnimationSampler().sample(of: clip.animation, in: window, at: time)
        // A clip holds at least one opacity keyframe, so the keyframes always give one.
        self.opacity = KeyframeTrack(keyframes: clip.opacity).value(at: time) ?? clip.opacity[0].value
        self.blend = clip.blend ?? "normal"
    }

    // MARK: - Public
    // MARK: - Private
}
