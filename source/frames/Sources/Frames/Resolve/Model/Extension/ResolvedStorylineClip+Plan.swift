//
//  ResolvedStorylineClip+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline clip as resolve decided it. Its crop is conformed to its box, the frame or under content fit the pixel
// size of its first crop, so evaluation fills the box with it as it is, and a clip written without a crop shows its
// whole picture, conformed the same way. A clip with a corner pin conforms it to the box its corner pin places. A
// solid's box is the frame at the origin, so its transform is the identity. A static crop is one keyframe at the
// clip's instant, and so is every other static property, but a tracked clip's crop true on the track's frame, which
// stays a static value.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: StorylinePlan,
        geometry: StorylineGeometry,
        format: FormatPlan,
        hashes: any FileHashProvider
    ) throws {
        let appearance = geometry.appearance
        let clipBox = appearance.box
            ?? ClipBox(size: format.size, position: .value(.point(format.frame.center)), anchor: format.frame.center)
        let cornerPin = appearance.cornerPin.map { pin in
            ResolvedCornerPin(size: pin.size, points: .keyframes(pin.points.keyframes(at: plan.instant) { $0 }))
        }
        let size = cornerPin?.size ?? clipBox.size
        let conformer = CropConformer()
        let box = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let conform = { (rectangle: Rectangle) in
            Crop(conformer.conformed(rectangle, to: box, by: format.conform))
        }
        let file: MediaFile?
        let whole: Size
        let content: ResolvedStorylineContent
        switch geometry.content {
        case let .solid(color):
            file = nil
            whole = format.size
            content = .solid(color)

        case let .file(media):
            file = media
            whole = media.size ?? format.size
            content = .media(ResolvedStorylineMedia(
                media: .pinned(try PinnedMedia(file: media, hashes: hashes)),
                colorSpace: plan.source.media?.colorSpace,
                isToneMapped: plan.source.media?.isToneMapped,
                timeRemap: plan.timeRemap
            ))

        case let .nested(nested):
            file = nil
            whole = nested.format.size
            content = .media(ResolvedStorylineMedia(
                media: .nested(try ResolvedSequence(plan: nested, hashes: hashes)),
                colorSpace: plan.source.media?.colorSpace,
                isToneMapped: plan.source.media?.isToneMapped,
                timeRemap: plan.timeRemap
            ))
        }
        let crop = geometry.crop?
            .followed(at: plan.instant, isOnTrackFrame: geometry.isCropOnTrackFrame) { conform($0) }
            ?? .keyframes([Keyframe(at: plan.instant, value: conform(Rectangle(x: 0, y: 0, width: whole.width, height: whole.height)))])

        self.init(
            place: plan.place.description,
            id: plan.id,
            content: content,
            in: plan.source.clipRange.start,
            out: plan.source.clipRange.end,
            speed: plan.source.speed,
            start: plan.edit.start,
            end: plan.edit.end,
            crop: crop,
            mask: geometry.mask,
            trackMatte: plan.trackMatte,
            track: try geometry.track.flatMap { track in
                try file.map { try ResolvedTrack(track: track, file: $0, hashes: hashes) }
            },
            filter: try geometry.filter.pinningFiles(hashes: hashes),
            box: cornerPin == nil
                ? ResolvedBox(
                    size: clipBox.size,
                    position: .keyframes(clipBox.position.keyframes(at: plan.instant) { $0 }),
                    anchor: clipBox.anchor
                )
                : nil,
            cornerPin: cornerPin,
            opacity: appearance.opacity.keyframes(at: plan.instant) { $0 },
            scale: cornerPin == nil ? (appearance.scale.keyframes(at: plan.instant) { $0 }) : nil,
            rotation: cornerPin == nil ? (appearance.rotation.keyframes(at: plan.instant) { $0 }) : nil,
            blend: appearance.blend,
            isMotionBlurred: plan.isMotionBlurred,
            radius: appearance.radius,
            border: appearance.border,
            shadow: appearance.shadow,
            transition: try plan.transition.map { try ResolvedTransition(plan: $0, hashes: hashes) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
