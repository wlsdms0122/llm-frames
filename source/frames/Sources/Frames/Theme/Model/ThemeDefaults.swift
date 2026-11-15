//
//  ThemeDefaults.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The choices a merged theme gives a clip that names none. `titleAnimations` is keyed by style, and a style it does
// not list takes none.
struct ThemeDefaults: Equatable, Sendable {
    // MARK: - Property
    let transition: ThemeDefault<TransitionChoice>
    let titleAnimations: [String: ThemeDefault<AnimationChoice>]
    let shapeAnimation: ThemeDefault<AnimationChoice>
    let mediaAnimation: ThemeDefault<AnimationChoice>
    let adjustAnimation: ThemeDefault<AnimationChoice>

    // MARK: - Initializer
    init(
        transition: ThemeDefault<TransitionChoice>,
        titleAnimations: [String: ThemeDefault<AnimationChoice>],
        shapeAnimation: ThemeDefault<AnimationChoice>,
        mediaAnimation: ThemeDefault<AnimationChoice>,
        adjustAnimation: ThemeDefault<AnimationChoice>
    ) {
        self.transition = transition
        self.titleAnimations = titleAnimations
        self.shapeAnimation = shapeAnimation
        self.mediaAnimation = mediaAnimation
        self.adjustAnimation = adjustAnimation
    }

    // MARK: - Public
    // MARK: - Private
}
