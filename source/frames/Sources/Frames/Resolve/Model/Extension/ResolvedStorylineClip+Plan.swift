//
//  ResolvedStorylineClip+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline clip as resolve decided it. Its crop is conformed to its box, the frame or under content fit the pixel
// size of its first crop, so evaluation fills the box with it as it is, and a clip written without a crop shows its
// whole picture, conformed the same way. A solid's box is the frame at the origin, so its transform is the identity. A
// static crop is one keyframe at the clip's `in`, and so is every other static property.
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
            ?? ClipBox(size: format.size, position: .value(Point(x: 0, y: 0)), anchor: format.frame.center)
        let conformer = CropConformer()
        let box = Rectangle(x: 0, y: 0, width: clipBox.size.width, height: clipBox.size.height)
        let conform = { (rectangle: Rectangle) in
            Crop(conformer.conformed(rectangle, to: box, by: format.conform))
        }
        let file: MediaFile? = if case let .file(file) = plan.source.media?.source { file } else { nil }
        let whole = geometry.nested?.format.size ?? file?.size ?? format.size
        let crop = geometry.crop?.keyframes(at: plan.instant) { conform($0.rectangle) }
            ?? [Keyframe(at: plan.instant, value: conform(Rectangle(x: 0, y: 0, width: whole.width, height: whole.height)))]

        self.init(
            place: plan.place.description,
            id: plan.id,
            media: try ResolvedMediaContent(media: plan.source.media, nested: geometry.nested, hashes: hashes),
            solid: geometry.color,
            in: plan.source.clipRange.start,
            out: plan.source.clipRange.end,
            speed: plan.source.speed,
            timeRemap: plan.timeRemap,
            start: plan.edit.start,
            end: plan.edit.end,
            crop: crop,
            mask: geometry.mask?.keyframes(at: plan.instant) { $0 },
            trackMatte: plan.trackMatte,
            track: try geometry.track.flatMap { track in
                try file.map { try ResolvedTrack(track: track, file: $0, hashes: hashes) }
            },
            filter: try geometry.filter.map { try ResolvedFilterOperation(operation: $0, hashes: hashes) },
            box: ResolvedBox(
                size: clipBox.size,
                position: clipBox.position.keyframes(at: plan.instant) { $0 },
                anchor: clipBox.anchor
            ),
            opacity: appearance.opacity.keyframes(at: plan.instant) { $0 },
            scale: appearance.scale.keyframes(at: plan.instant) { $0 },
            rotation: appearance.rotation.keyframes(at: plan.instant) { $0 },
            blend: appearance.blend,
            radius: appearance.radius,
            border: appearance.border,
            shadow: appearance.shadow,
            transition: try plan.transition.map { try ResolvedTransition(plan: $0, hashes: hashes) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
