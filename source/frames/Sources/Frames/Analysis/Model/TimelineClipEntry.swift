//
//  TimelineClipEntry.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `sound` is the range a visual media clip's sound plays over, its split applied, nil for every other clip and for one
// that plays no sound. `lane` is nil for a sound, `storyline` is the place of the storyline clip a connected clip
// belongs to, and `parent` is the place of the clip whose space a parented clip is placed in.
struct TimelineClipEntry: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let kind: String
    let visible: TimeRange
    let sound: TimeRange?
    let lane: Int?
    let storyline: String?
    let parent: String?
    let animation: TimelineAnimation?
    let nested: TimelineReport?

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        kind: String,
        visible: TimeRange,
        sound: TimeRange?,
        lane: Int?,
        storyline: String?,
        parent: String?,
        animation: TimelineAnimation?,
        nested: TimelineReport?
    ) {
        self.place = place
        self.id = id
        self.kind = kind
        self.visible = visible
        self.sound = sound
        self.lane = lane
        self.storyline = storyline
        self.parent = parent
        self.animation = animation
        self.nested = nested
    }

    // MARK: - Public
    // MARK: - Private
}
