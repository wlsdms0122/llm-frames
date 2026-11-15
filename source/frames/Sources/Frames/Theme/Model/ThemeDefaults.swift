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
    let transition: TransitionChoice
    let titleAnimations: [String: AnimationChoice]
    let shapeAnimation: AnimationChoice
    let mediaAnimation: AnimationChoice
    let adjustAnimation: AnimationChoice

    // MARK: - Initializer
    init(
        transition: TransitionChoice,
        titleAnimations: [String: AnimationChoice],
        shapeAnimation: AnimationChoice,
        mediaAnimation: AnimationChoice,
        adjustAnimation: AnimationChoice
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
