//
//  ResolvedStorylineClip+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline clip as resolve decided it. Its crop is conformed to its box, the frame or under content fit the pixel
// size of its first crop, so evaluation fills the box with it as it is, and a clip written without a crop shows its
// whole picture, conformed the same way. A clip with a corner pin conforms it to the box its corner pin places. A
// solid fills the frame. A static crop is one keyframe at the clip's instant, and so is every other static property,
// but a tracked clip's crop true on the track's frame, which stays a static value.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: StorylinePlan,
        geometry: StorylineGeometry,
        format: FormatPlan,
        hashes: any FileHashProvider
    ) throws {
        let content: ResolvedStorylineContent
        switch geometry.content {
        case let .solid(color):
            content = .solid(ResolvedSolid(color: color, size: format.size, conform: format.conform))

        case let .file(media):
            content = .media(ResolvedStorylineMedia(
                media: .pinned(try PinnedMedia(file: media, hashes: hashes)),
                colorSpace: plan.source.media?.colorSpace,
                isToneMapped: plan.source.media?.isToneMapped,
                timeRemap: plan.timeRemap,
                picture: try Self.picture(of: plan, geometry: geometry, whole: media.size ?? format.size, file: media, format: format, hashes: hashes)
            ))

        case let .nested(nested):
            content = .media(ResolvedStorylineMedia(
                media: .nested(try ResolvedSequence(plan: nested, hashes: hashes)),
                colorSpace: plan.source.media?.colorSpace,
                isToneMapped: plan.source.media?.isToneMapped,
                timeRemap: plan.timeRemap,
                picture: try Self.picture(of: plan, geometry: geometry, whole: nested.format.size, file: nil, format: format, hashes: hashes)
            ))
        }

        self.init(
            place: plan.place.description,
            id: plan.id,
            content: content,
            in: plan.source.clipRange.start,
            out: plan.source.clipRange.end,
            speed: plan.source.speed,
            start: plan.edit.start,
            end: plan.edit.end,
            isMotionBlurred: plan.isMotionBlurred,
            transition: try plan.transition.map { try ResolvedTransition(plan: $0, hashes: hashes) }
        )
    }

    // MARK: - Public
    // MARK: - Private
    // The picture of an entry with media, `whole` its picture's size and `file` its media file, nil for a nested
    // sequence, which no track follows.
    private static func picture(
        of plan: StorylinePlan,
        geometry: StorylineGeometry,
        whole: Size,
        file: MediaFile?,
        format: FormatPlan,
        hashes: any FileHashProvider
    ) throws -> ResolvedStorylinePicture {
        let appearance = geometry.appearance
        let clipBox = appearance.box
            ?? ClipBox(size: format.size, position: .value(.point(format.frame.center)), anchor: format.frame.center)
        let placement: ResolvedStorylinePlacement = if let pin = appearance.cornerPin {
            .cornerPin(ResolvedCornerPin(
                size: pin.size,
                points: .keyframes(pin.points.keyframes(at: plan.instant) { $0 })
            ))
        } else {
            .transform(
                box: ResolvedBox(
                    size: clipBox.size,
                    position: .keyframes(clipBox.position.keyframes(at: plan.instant) { $0 }),
                    anchor: clipBox.anchor
                ),
                scale: appearance.scale.keyframes(at: plan.instant) { $0 },
                rotation: appearance.rotation.keyframes(at: plan.instant) { $0 }
            )
        }
        let size = placement.size
        let conformer = CropConformer()
        let box = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let conform = { (rectangle: Rectangle) in
            Crop(conformer.conformed(rectangle, to: box, by: format.conform))
        }
        let crop = geometry.crop?
            .followed(at: plan.instant, isOnTrackFrame: geometry.isCropOnTrackFrame) { conform($0) }
            ?? .keyframes([Keyframe(at: plan.instant, value: conform(Rectangle(x: 0, y: 0, width: whole.width, height: whole.height)))])

        return ResolvedStorylinePicture(
            placement: placement,
            crop: crop,
            mask: geometry.mask,
            trackMatte: plan.trackMatte,
            track: try geometry.track.flatMap { track in
                try file.map { try ResolvedTrack(track: track, file: $0, hashes: hashes) }
            },
            filter: try geometry.filter.pinningFiles(hashes: hashes),
            opacity: appearance.opacity.keyframes(at: plan.instant) { $0 },
            blend: appearance.blend,
            radius: appearance.radius,
            border: appearance.border,
            shadow: appearance.shadow
        )
    }
}
