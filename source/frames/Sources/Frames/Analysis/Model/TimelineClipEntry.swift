//
//  TimelineClipEntry.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `lane` is nil for a sound, and `parent` is the place of the clip whose space a parented clip is placed in.
struct TimelineClipEntry: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let kind: String
    let visible: TimeRange
    let lane: Int?
    let parent: String?
    let animation: TimelineAnimation?
    let nested: TimelineReport?

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        kind: String,
        visible: TimeRange,
        lane: Int?,
        parent: String?,
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
