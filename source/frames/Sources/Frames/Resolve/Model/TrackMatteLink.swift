//
//  TrackMatteLink.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A clip of a document as its track matte chains see it, its place and kind as messages name them. `refusal` is the
// kind that keeps it from being a track matte, nil for a connected or sequence media clip, title or shape.
struct TrackMatteLink: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let kind: PlaceKind
    let id: String?
    let trackMatte: TrackMatte?
    let refusal: TrackMatteRefusal?

    // MARK: - Initializer
    init(
        place: Place,
        kind: PlaceKind,
        id: String?,
        trackMatte: TrackMatte?,
        refusal: TrackMatteRefusal?
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
