//
//  ResolvedStorylineClip+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A storyline clip as resolve decided it. Its crop is conformed to the content rect, so evaluation fills that rect with
// it as it is, and a clip written without a crop shows its whole picture, conformed the same way. A static crop is one
// keyframe at the clip's `in`.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: StorylinePlan,
        geometry: StorylineGeometry,
        format: FormatPlan,
        hashes: any FileHashProvider
    ) throws {
        let conformer = CropConformer()
        let conform = { (rectangle: Rectangle) in
            Crop(conformer.conformed(rectangle, to: format.content, by: format.conform))
        }
        let file: MediaFile? = if case let .file(file) = plan.source.media?.source { file } else { nil }
        let whole = geometry.nested?.format.size ?? file?.size ?? Size(width: format.content.width, height: format.content.height)
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
            start: plan.edit.start,
            end: plan.edit.end,
            crop: crop,
            track: geometry.track.map { ResolvedTrack(track: $0, values: geometry.crop) },
            filter: try geometry.filter.map { try ResolvedFilterOperation(operation: $0, hashes: hashes) },
            transition: try plan.transition.map { try ResolvedTransition(plan: $0, hashes: hashes) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
