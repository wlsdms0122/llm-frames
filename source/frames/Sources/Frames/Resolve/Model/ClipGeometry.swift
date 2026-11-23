//
//  ClipGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found and set for a connected or sequence clip, with keyframes in sequence time. `area`, a path's
// `points` and `position` are in the space a parented clip's parent gives, and an unparented clip's in output pixels.
// `crop` is in the clip's own media and `mask` in the clip's own coordinate space. Under content fit output pixels are
// the measuring space, so a clip with `isInOutputPixels` moves with the content. `box` is where a title, a media clip
// or a shape given by `width` and `height` is drawn, and `position` the anchor point it was found from. `cornerPin` is
// where such a clip is drawn when its corner pin places it, and it then has no `box`. `onTrackFrame` names the followed
// values of a tracked clip written without keyframes that are true on the track's frame. A path's vertices are as its
// entry holds them, each leaf decided on its own.
struct ClipGeometry: Equatable, Sendable {
    // MARK: - Property
    let area: PropertyValue<AreaValue>?
    let points: [PathVertex<FollowedValue<GeometryPoint>, FollowedValue<Point>>]?
    let position: PropertyValue<GeometryPoint>?
    let box: ClipBox?
    let cornerPin: ClipCornerPin?
    let crop: PropertyValue<FoundArea>?
    let mask: [ResolvedMask]?
    let track: TrackedMedia?
    let onTrackFrame: Set<FollowedKey>
    let isInOutputPixels: Bool
    let title: TitlePlan?
    let nested: SequencePlan?
    let appearance: ClipAppearance

    // MARK: - Initializer
    init(
        area: PropertyValue<AreaValue>?,
        points: [PathVertex<FollowedValue<GeometryPoint>, FollowedValue<Point>>]? = nil,
        position: PropertyValue<GeometryPoint>?,
        box: ClipBox?,
        cornerPin: ClipCornerPin? = nil,
        crop: PropertyValue<FoundArea>?,
        mask: [ResolvedMask]?,
        track: TrackedMedia?,
        onTrackFrame: Set<FollowedKey> = [],
        isInOutputPixels: Bool,
        title: TitlePlan?,
        nested: SequencePlan?,
        appearance: ClipAppearance
    ) {
        self.area = area
        self.points = points
        self.position = position
        self.box = box
        self.cornerPin = cornerPin
        self.crop = crop
        self.mask = mask
        self.track = track
        self.onTrackFrame = onTrackFrame
        self.isInOutputPixels = isInOutputPixels
        self.title = title
        self.nested = nested
        self.appearance = appearance
    }

    // MARK: - Public
    // MARK: - Private
}
