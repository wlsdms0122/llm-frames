//
//  ResolvedComposite.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How a clips entry's picture composites onto what is below it: the signed `lane` it is stacked in, its `opacity`
// keyframes in sequence time, its `blend` mode, its `mask`, the masks in the clip's own coordinate space, nil for none,
// a keyframe's where it lies at its own time when tracked, and its `trackMatte`, nil for none.
struct ResolvedComposite: Equatable, Sendable {
    // MARK: - Property
    let lane: Int
    let opacity: [Keyframe<Double>]
    let blend: String
    let mask: [ResolvedMask]?
    let trackMatte: TrackMatte?

    // MARK: - Initializer
    init(
        lane: Int,
        opacity: [Keyframe<Double>],
        blend: String,
        mask: [ResolvedMask]? = nil,
        trackMatte: TrackMatte? = nil
    ) {
        self.lane = lane
        self.opacity = opacity
        self.blend = blend
        self.mask = mask
        self.trackMatte = trackMatte
    }

    // MARK: - Public
    // MARK: - Private
}
