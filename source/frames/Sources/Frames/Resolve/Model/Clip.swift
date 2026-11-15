//
//  Clip.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A connected or sequence clip as written.
struct Clip: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let clipPlace: ClipPlace
    let content: ClipContent
    let at: ClipWindow?
    let lane: Int?
    let hasParent: Bool
    let hasPlacement: Bool
    let hasArea: Bool
    let animation: AnimationChoice?
    let keyframes: [KeyframeInstant]

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        clipPlace: ClipPlace,
        content: ClipContent,
        at: ClipWindow?,
        lane: Int?,
        hasParent: Bool,
        hasPlacement: Bool,
        hasArea: Bool,
        animation: AnimationChoice?,
        keyframes: [KeyframeInstant]
    ) {
        self.place = place
        self.id = id
        self.clipPlace = clipPlace
        self.content = content
        self.at = at
        self.lane = lane
        self.hasParent = hasParent
        self.hasPlacement = hasPlacement
        self.hasArea = hasArea
        self.animation = animation
        self.keyframes = keyframes
    }

    // MARK: - Public
    // MARK: - Private
}
