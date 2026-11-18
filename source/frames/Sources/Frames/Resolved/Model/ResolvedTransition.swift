//
//  ResolvedTransition.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A transition's picture by its range in sequence time, the storyline picture on top, and its spans inline, with its
// cover and matte media pinned. The curve of its sound crossfade is on each sound it crossfades.
struct ResolvedTransition: Equatable, Sendable {
    // MARK: - Property
    let start: Double
    let end: Double
    let over: TransitionOrder
    let incoming: Span?
    let outgoing: Span?
    let cover: ResolvedCover?
    let matte: ResolvedMatte?

    // MARK: - Initializer
    init(
        start: Double,
        end: Double,
        over: TransitionOrder,
        incoming: Span?,
        outgoing: Span?,
        cover: ResolvedCover?,
        matte: ResolvedMatte?
    ) {
        self.start = start
        self.end = end
        self.over = over
        self.incoming = incoming
        self.outgoing = outgoing
        self.cover = cover
        self.matte = matte
    }

    // MARK: - Public
    // MARK: - Private
}
