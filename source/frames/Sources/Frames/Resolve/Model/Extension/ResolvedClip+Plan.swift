//
//  ResolvedClip+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A connected or sequence clip as resolve decided it, every static property one keyframe at the clip's instant but a
// followed value true on the track's frame, which stays a static value. A title, a media clip or a shape given by
// `width` and `height` carries its box, or its corner pin where one places it, and a shape placed by its geometry
// carries its placement in its own entry. Scale and rotation belong to anything drawn but an adjustment and a clip with
// a corner pin.
extension ResolvedClip {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: ClipPlan,
        geometry: ClipGeometry,
        hashes: any FileHashProvider
    ) throws {
        let instant = plan.instant
        let appearance = geometry.appearance
        let onTrackFrame = geometry.onTrackFrame
        let content = try Self.content(of: plan, geometry: geometry, hashes: hashes)
        let isTransformed = if case .adjustment = content { false } else { geometry.cornerPin == nil }

        self.init(
            place: plan.place.description,
            id: plan.id,
            content: content,
            start: plan.visible.start,
            end: plan.visible.end,
            lane: plan.lane,
            storyline: plan.storyline,
            parent: plan.parent?.id,
            box: geometry.box.map { box in
                ResolvedBox(
                    size: box.size,
                    position: box.position.followed(at: instant, isOnTrackFrame: onTrackFrame.contains(.position)) { $0 },
                    anchor: box.anchor
                )
            },
            cornerPin: geometry.cornerPin.map { pin in
                ResolvedCornerPin(
                    size: pin.size,
                    points: pin.points.followed(at: instant, isOnTrackFrame: onTrackFrame.contains(.cornerPin)) { $0 }
                )
            },
            crop: appearance.media?.crop
                .followed(at: instant, isOnTrackFrame: onTrackFrame.contains(.crop)) { Crop($0) },
            mask: geometry.mask,
            trackMatte: plan.trackMatte,
            track: try geometry.track.map { try ResolvedTrack(track: $0, hashes: hashes) },
            opacity: appearance.opacity.keyframes(at: instant) { $0 },
            scale: isTransformed ? appearance.scale.keyframes(at: instant) { $0 } : nil,
            rotation: isTransformed ? appearance.rotation.keyframes(at: instant) { $0 } : nil,
            blend: appearance.blend,
            isMotionBlurred: plan.isMotionBlurred,
            animation: ResolvedAnimation(plan: plan.animation)
        )
    }

    // MARK: - Public
    // MARK: - Private
    // A title is the one clip set as text, a shape the one with a shape appearance, and a media clip the one with a
    // picture that fills its box, so what is left is an adjustment.
    private static func content(
        of plan: ClipPlan,
        geometry: ClipGeometry,
        hashes: any FileHashProvider
    ) throws -> ResolvedClipContent {
        let appearance = geometry.appearance
        let filter = try appearance.filter.pinningFiles(hashes: hashes)

        if let title = geometry.title {
            return .title(try ResolvedText(plan: title, hashes: hashes))
        }
        if let shape = appearance.shape {
            return .shape(ResolvedShape(shape: shape, geometry: geometry, instant: plan.instant))
        }
        if
            let media = try ResolvedMediaContent(media: plan.media, nested: geometry.nested, hashes: hashes),
            let fill = appearance.media
        {
            return .media(ResolvedMediaClip(
                media: media,
                colorSpace: plan.media?.colorSpace,
                isToneMapped: plan.media?.isToneMapped,
                timing: plan.timing,
                filter: filter,
                appearance: ResolvedMediaAppearance(
                    conform: fill.conform,
                    radius: fill.radius,
                    border: fill.border,
                    shadow: fill.shadow
                )
            ))
        }

        return .adjustment(filter)
    }
}
