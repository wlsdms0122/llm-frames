//
//  TrackMatteLink.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A clip of a document as its track matte chains see it, its place and kind as messages name them. `refusal` is the
// kind that keeps it from being a track matte, nil for a connected or sequence media clip, title or shape, and
// `areaRefusal` the kind that keeps a clip area from naming it: a clip area reads a box and not a picture, so a null,
// which has a box and draws nothing, may be named by one.
struct TrackMatteLink: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let kind: PlaceKind
    let id: String?
    let trackMatte: TrackMatte?
    let refusal: TrackMatteRefusal?

    var areaRefusal: TrackMatteRefusal? {
        refusal == .null ? nil : refusal
    }

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
