//
//  ResolvedTransition.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A transition by its range in sequence time, the storyline picture on top, the curve of its sound crossfade, and its
// spans inline, with its cover and matte media pinned.
struct ResolvedTransition: Equatable, Sendable {
    // MARK: - Property
    let start: Double
    let end: Double
    let over: TransitionOrder
    let audio: CrossfadeCurve
    let incoming: Span?
    let outgoing: Span?
    let cover: ResolvedCover?
    let matte: ResolvedMatte?

    // MARK: - Initializer
    init(
        start: Double,
        end: Double,
        over: TransitionOrder,
        audio: CrossfadeCurve,
        incoming: Span?,
        outgoing: Span?,
        cover: ResolvedCover?,
        matte: ResolvedMatte?
    ) {
        self.start = start
        self.end = end
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
