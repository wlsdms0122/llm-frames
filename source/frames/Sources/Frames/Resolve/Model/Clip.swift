//
//  Clip.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A connected or sequence clip as written, its keyframes on the clip's clock. `parent` is the id the clip names.
// `width` is a title's wrapping width, and with `height` and `conform` a media clip's box. `radius`, `border` and
// `shadow` are a media clip's; a shape's own keys are in its content. `animation` and `filter` are preset choices
// as written, which resolve merges over the theme's defaults, `filter` with its keyframes; `filter` is a media clip's
// `filter` or an adjustment's `adjust`.
struct Clip: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let clipPlace: ClipPlace
    let content: ClipContent
    let at: ClipWindow?
    let lane: Int?
    let parent: String?
    let placement: String?
    let anchor: String?
    let animation: JSONValue?
    let keyframes: [KeyframeInstant]
    let area: PropertyValue<AreaForm>?
    let position: PropertyValue<PositionForm>?
    let crop: PropertyValue<CropForm>?
    let mask: PropertyValue<[ClipMask]>?
    let trackMatte: TrackMatte?
    let track: TrackTarget?
    let width: Double?
    let height: Double?
    let conform: Conform?
    let radius: LookProperty?
    let border: LookProperty?
    let shadow: LookProperty?
    let opacity: PropertyValue<Double>?
    let scale: PropertyValue<Double>?
    let rotation: PropertyValue<Double>?
    let blend: String?
    let filter: LookProperty?

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        clipPlace: ClipPlace,
        content: ClipContent,
        at: ClipWindow?,
        lane: Int?,
        parent: String? = nil,
        placement: String? = nil,
        anchor: String? = nil,
        animation: JSONValue?,
        keyframes: [KeyframeInstant],
        area: PropertyValue<AreaForm>? = nil,
        position: PropertyValue<PositionForm>? = nil,
        crop: PropertyValue<CropForm>? = nil,
        mask: PropertyValue<[ClipMask]>? = nil,
        trackMatte: TrackMatte? = nil,
        track: TrackTarget? = nil,
        width: Double? = nil,
        height: Double? = nil,
        conform: Conform? = nil,
        radius: LookProperty? = nil,
        border: LookProperty? = nil,
        shadow: LookProperty? = nil,
        opacity: PropertyValue<Double>? = nil,
        scale: PropertyValue<Double>? = nil,
        rotation: PropertyValue<Double>? = nil,
        blend: String? = nil,
        filter: LookProperty? = nil
    ) {
        self.place = place
        self.id = id
        self.clipPlace = clipPlace
        self.content = content
        self.at = at
        self.lane = lane
        self.parent = parent
        self.placement = placement
        self.anchor = anchor
        self.animation = animation
        self.keyframes = keyframes
        self.area = area
        self.position = position
        self.crop = crop
        self.mask = mask
        self.trackMatte = trackMatte
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
        self.filter = filter
    }

    // MARK: - Public
    // MARK: - Private
}
