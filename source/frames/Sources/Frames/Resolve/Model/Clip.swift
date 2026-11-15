//
//  Clip.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A connected or sequence clip as written, with the geometry resolve finds and the text it sets. `area`, `position`
// and `crop` are as written, their keyframes on the clip's clock. `width` is a title's wrapping width.
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
    let area: PropertyValue<AreaForm>?
    let position: PropertyValue<PositionForm>?
    let crop: PropertyValue<CropForm>?
    let track: TrackTarget?
    let label: String?
    let side: Side?
    let width: Double?

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
        keyframes: [KeyframeInstant],
        area: PropertyValue<AreaForm>? = nil,
        position: PropertyValue<PositionForm>? = nil,
        crop: PropertyValue<CropForm>? = nil,
        track: TrackTarget? = nil,
        label: String? = nil,
        side: Side? = nil,
        width: Double? = nil
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
        self.area = area
        self.position = position
        self.crop = crop
        self.track = track
        self.label = label
        self.side = side
        self.width = width
    }

    // MARK: - Public
    // MARK: - Private
}
