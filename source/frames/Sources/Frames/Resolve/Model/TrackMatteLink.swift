//
//  TrackMatteLink.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A clip of a document as its track matte chains see it, its place and kind as messages name them. `refusal` is the
// kind that keeps it from being a track matte, nil for a connected or sequence media clip, title or shape, and
// `areaRefusal` the kind that keeps a clip area from naming it: a clip area reads a box and not a picture, so a null,
// which has a box and draws nothing, and a storyline clip with media may be named by one, and a storyline solid may
// not.
struct TrackMatteLink: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let kind: PlaceKind
    let id: String?
    let trackMatte: TrackMatte?
    let refusal: TrackMatteRefusal?

    var areaRefusal: ClipAreaRefusal? {
        switch refusal {
        case .storyline:
            kind == .clip(.solid) ? .solid : nil

        case .adjustment:
            .adjustment

        case .audio:
            .audio

        case .null, nil:
            nil
        }
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
