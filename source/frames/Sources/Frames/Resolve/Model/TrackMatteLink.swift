//
//  TrackMatteLink.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A clip of a document as its track matte chains see it: its place and kind as messages name them, its id, the track
// matte it names, and `refusal`, what it is in a message's words when it cannot be a track matte (a storyline clip,
// an adjustment clip or an audio clip), nil for a connected or sequence media clip, title or shape (FRAMES-11).
struct TrackMatteLink: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let kind: PlaceKind
    let id: String?
    let trackMatte: TrackMatte?
    let refusal: String?

    // MARK: - Initializer
    init(
        place: Place,
        kind: PlaceKind,
        id: String?,
        trackMatte: TrackMatte?,
        refusal: String?
    ) {
        self.place = place
        self.kind = kind
        self.id = id
        self.trackMatte = trackMatte
        self.refusal = refusal
    }

    // MARK: - Public
    // MARK: - Private
}
