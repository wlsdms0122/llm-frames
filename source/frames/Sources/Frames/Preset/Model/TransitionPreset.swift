//
//  TransitionPreset.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `audio` is the curve of the sound crossfade, which runs over the transition at an even pace whatever its `ease`.
struct TransitionPreset: Equatable, Sendable {
    // MARK: - Property
    let description: String
    let seconds: Double
    let over: TransitionOrder
    let audio: CrossfadeCurve
    let incoming: Span?
    let outgoing: Span?
    let cover: Cover?
    let matte: Matte?

    // MARK: - Initializer
    init(
        description: String,
        seconds: Double,
        over: TransitionOrder,
        audio: CrossfadeCurve,
        incoming: Span?,
        outgoing: Span?,
        cover: Cover?,
        matte: Matte?
    ) {
        self.description = description
        self.seconds = seconds
        self.over = over
        self.audio = audio
        self.incoming = incoming
        self.outgoing = outgoing
        self.cover = cover
        self.matte = matte
    }

    // MARK: - Public
    // MARK: - Private
}
