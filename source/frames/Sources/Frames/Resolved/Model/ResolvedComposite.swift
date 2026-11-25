//
//  ResolvedComposite.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How a clips entry's picture composites onto what is below it: the signed `lane` it is stacked in, its `opacity`
// keyframes in sequence time and its `blend` mode.
struct ResolvedComposite: Equatable, Sendable {
    // MARK: - Property
    let lane: Int
    let opacity: [Keyframe<Double>]
    let blend: String

    // MARK: - Initializer
    init(
        lane: Int,
        opacity: [Keyframe<Double>],
        blend: String
    ) {
        self.lane = lane
        self.opacity = opacity
        self.blend = blend
    }

    // MARK: - Public
    // MARK: - Private
}
