//
//  ResolvedClip+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A connected or sequence clip as resolve decided it, every static property one keyframe at the clip's instant but a
// followed value true on the track's frame, which stays a static value. A title, a media clip, or a shape or a null
// given by `width` and `height` carries its box in its transform, or its corner pin where one places it, a shape or a
// null placed by its geometry carries its placement in its own entry, and an adjustment is placed by its box alone.
extension ResolvedClip {
    // MARK: - Property
    // MARK: - Initializer
    // An audio clip draws nothing and has no clips entry: its sound is one of the sequence's audio entries.
    init?(
        plan: ClipPlan,
        geometry: ClipGeometry,
        hashes: any FileHashProvider
    ) throws {
        let instant = plan.instant
        let appearance = geometry.appearance
        let onTrackFrame = geometry.onTrackFrame
        let content: ResolvedClipContent
        switch appearance.drawing {
        case let .picture(composite):
            content = .picture(
                try Self.picture(of: plan, geometry: geometry, hashes: hashes),
                ResolvedComposite(
                    lane: composite.lane,
                    opacity: composite.opacity.keyframes(at: instant) { $0 },
                    blend: composite.blend,
                    mask: geometry.mask,
                    trackMatte: plan.trackMatte
                )
            )

        case let .null(null):
            content = .null(ResolvedNull(geometry: NullGeometry(plan: null, geometry: geometry, instant: instant)))

        case .sound:
            return nil
        }
        let box = geometry.box.map { box in
            ResolvedBox(
                size: box.size,
                position: box.position.followed(at: instant, isOnTrackFrame: onTrackFrame.contains(.position)) { $0 },
                anchor: box.anchor
            )
        }
        let placement: ResolvedPlacement = if case .picture(.adjustment, _) = content {
            .box(box)
        } else if let pin = geometry.cornerPin {
            .cornerPin(ResolvedCornerPin(
                size: pin.size,
                points: pin.points.followed(at: instant, isOnTrackFrame: onTrackFrame.contains(.cornerPin)) { $0 }
            ))
        } else {
            .transform(ResolvedTransform(
                box: box,
                scale: appearance.scale.keyframes(at: instant) { $0 },
                rotation: appearance.rotation.keyframes(at: instant) { $0 }
            ))
        }

        self.init(
            place: plan.place.description,
            id: plan.id,
            content: content,
            start: plan.visible.start,
            end: plan.visible.end,
            storyline: plan.storyline,
            parent: plan.parent?.id,
            placement: placement,
            track: try geometry.track.map { try ResolvedTrack(track: $0, hashes: hashes) },
            isMotionBlurred: plan.isMotionBlurred,
            animation: ResolvedAnimation(plan: plan.animation)
        )
    }

    // MARK: - Public
    // MARK: - Private
    // A title is the one clip set as text, a shape the one with a shape appearance, and a media clip the one with a
    // picture that fills its box, so what is left is an adjustment.
    private static func picture(
        of plan: ClipPlan,
        geometry: ClipGeometry,
        hashes: any FileHashProvider
    ) throws -> ResolvedPicture {
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
                crop: fill.crop.followed(at: plan.instant, isOnTrackFrame: geometry.onTrackFrame.contains(.crop)) { Crop($0) },
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
