//
//  TimelineClipEntry.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `lane` is nil for a sound, and `parent` is the place of the storyline clip a parented clip is composited with.
struct TimelineClipEntry: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let kind: String
    let visible: TimeRange
    let lane: Int?
    let parent: Place?
    let animation: TimelineAnimation?
    let nested: TimelineReport?

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        kind: String,
        visible: TimeRange,
        lane: Int?,
        parent: Place?,
        animation: TimelineAnimation?,
        nested: TimelineReport?
    ) {
        self.place = place
        self.id = id
        self.kind = kind
        self.visible = visible
        self.lane = lane
        self.parent = parent
        self.animation = animation
        self.nested = nested
    }

    // MARK: - Public
    // MARK: - Private
}
