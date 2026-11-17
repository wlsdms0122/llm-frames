//
//  Clip.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A connected or sequence clip as written, with the geometry resolve finds and the text it sets. `area`, `position`
// and `crop` are as written, their keyframes on the clip's clock. `placement` and `anchor` are the names written.
// `width` is a title's wrapping width, and with `height` and `conform` a media clip's box. `radius`, `border` (the
// theme border or the colour written) and `shadow` are a media clip's. `opacity`, `scale` and `rotation` are as
// written, their keyframes on the clip's clock, `color` is a shape's as written, and `filter` the filter choice: a
// media clip's `filter`, or an adjustment's `adjust`.
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
    let placement: String?
    let anchor: String?
    let animation: AnimationChoice?
    let keyframes: [KeyframeInstant]
    let area: PropertyValue<AreaForm>?
    let position: PropertyValue<PositionForm>?
    let crop: PropertyValue<CropForm>?
    let track: TrackTarget?
    let width: Double?
    let height: Double?
    let conform: Conform?
    let radius: Double?
    let border: BorderForm?
    let shadow: Bool
    let opacity: PropertyValue<Double>?
    let scale: PropertyValue<Double>?
    let rotation: PropertyValue<Double>?
    let blend: String?
    let color: String?
    let filter: JSONValue?

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
        placement: String? = nil,
        anchor: String? = nil,
        animation: AnimationChoice?,
        keyframes: [KeyframeInstant],
        area: PropertyValue<AreaForm>? = nil,
        position: PropertyValue<PositionForm>? = nil,
        crop: PropertyValue<CropForm>? = nil,
        track: TrackTarget? = nil,
        width: Double? = nil,
        height: Double? = nil,
        conform: Conform? = nil,
        radius: Double? = nil,
        border: BorderForm? = nil,
        shadow: Bool = false,
        opacity: PropertyValue<Double>? = nil,
        scale: PropertyValue<Double>? = nil,
        rotation: PropertyValue<Double>? = nil,
        blend: String? = nil,
        color: String? = nil,
        filter: JSONValue? = nil
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
        self.placement = placement
        self.anchor = anchor
        self.animation = animation
        self.keyframes = keyframes
        self.area = area
        self.position = position
        self.crop = crop
        self.track = track
        self.width = width
        self.height = height
        self.conform = conform
        self.radius = radius
        self.border = border
        self.shadow = shadow
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.blend = blend
        self.color = color
        self.filter = filter
    }

    // MARK: - Public
    // MARK: - Private
}
