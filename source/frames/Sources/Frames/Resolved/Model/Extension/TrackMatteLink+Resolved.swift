//
//  TrackMatteLink+Resolved.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A resolved entry as its track matte chains see it, at the place it is read from. Audio clips are not among the
// clips entries, so they are named by no id.
extension TrackMatteLink {
    // MARK: - Property
    // MARK: - Initializer
    // A storyline clip is never a track matte.
    init(
        entry: ResolvedStorylineClip,
        place: Place
    ) {
        self.init(
            place: place,
            kind: .genericClip(.storyline),
            id: entry.id,
            trackMatte: entry.trackMatte,
            refusal: "a storyline clip"
        )
    }

    // An adjustment draws no picture of its own, so it is not a track matte.
    init(
        clip: ResolvedClip,
        place: Place,
        kind: PlaceKind
    ) {
        let refusal: String? = if case .adjustment = clip.content { "an adjustment clip" } else { nil }

        self.init(place: place, kind: kind, id: clip.id, trackMatte: clip.trackMatte, refusal: refusal)
    }

    // MARK: - Public
    // MARK: - Private
}
