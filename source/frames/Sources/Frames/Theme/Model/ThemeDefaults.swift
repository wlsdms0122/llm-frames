//
//  ThemeDefaults.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The choices a merged theme gives a clip that names none. `titleAnimations` is keyed by style, and a style it does
// not list takes none. The default filter is read from the theme where a clip takes it, since its entries are timed
// with the clip's keyframes.
struct ThemeDefaults: Equatable, Sendable {
    // MARK: - Property
    let transition: TransitionChoice
    let titleAnimations: [String: AnimationChoice]
    let shapeAnimation: AnimationChoice
    let mediaAnimation: AnimationChoice
    let adjustmentAnimation: AnimationChoice

    // MARK: - Initializer
    init(
        transition: TransitionChoice,
        titleAnimations: [String: AnimationChoice],
        shapeAnimation: AnimationChoice,
        mediaAnimation: AnimationChoice,
        adjustmentAnimation: AnimationChoice
    ) {
        self.transition = transition
        self.titleAnimations = titleAnimations
        self.shapeAnimation = shapeAnimation
        self.mediaAnimation = mediaAnimation
        self.adjustmentAnimation = adjustmentAnimation
    }

    // MARK: - Public
    // MARK: - Private
}
