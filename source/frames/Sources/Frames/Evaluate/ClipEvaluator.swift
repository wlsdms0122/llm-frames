//
//  ClipEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Evaluates one clips entry at an instant into the items it draws, bottom first, in the coordinates of the space it is
// composited in: its keyframes sampled, its animation over its visible window combined on top, and its blend. A title
// or media clip is drawn in its box's own pixels, its box's top left at its position and scale and rotation about its
// anchor point. A shape or adjustment is drawn in the space's coordinates on its area, or without one over the frame.
struct ClipEvaluator: Sendable {
    // MARK: - Property
    private let shapeEvaluator = ShapeEvaluator()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `picture` is a media clip's picture at the time, and nil for any other clip.
    func items(
        of clip: ResolvedClip,
        in space: ClipSpace,
        picture: PictureItemSource?,
        at time: Double
    ) -> [DisplayItem] {
        let sample = ClipSample(clip: clip, at: time)

        switch clip.content {
        case let .title(text):
            // A title carries its box.
            guard let box = clip.box else { return [] }

            let glyphs = GlyphsItem(text: text)
            return [boxItem(of: clip, box: box, sample: sample, in: space, content: .glyphs(glyphs), at: time)]

        case let .media(media):
            // A media clip carries its box and every crop conformed to it, and its picture is given.
            guard let box = clip.box, let picture else { return [] }

            let item = PictureItem(
                source: picture,
                rectangle: clip.crop.map { $0.value(at: time).rectangle },
                destination: Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height),
                filter: media.filter,
                radius: media.appearance.radius,
                border: media.appearance.border,
                shadow: media.appearance.shadow
            )
            return [boxItem(of: clip, box: box, sample: sample, in: space, content: .picture(item), at: time)]

        case let .shape(drawing):
            return shapeEvaluator.items(of: drawing, clip: clip, sample: sample, in: space, at: time)

        case let .adjustment(filter):
            return [adjustItem(of: clip, filter: filter, sample: sample, in: space, at: time)]
        }
    }

    // MARK: - Private
    // A title or media clip's item in its box's own pixels, wiped across its box from the animation's side.
    private func boxItem(
        of clip: ResolvedClip,
        box: ResolvedBox,
        sample: ClipSample,
        in space: ClipSpace,
        content: DisplayContent,
        at time: Double
    ) -> DisplayItem {
        let values = KeyframedValues(
            position: space.position(of: box, track: clip.track, at: time),
            scale: clip.scale.map { $0.value(at: time) } ?? 1,
            rotation: clip.rotation.map { $0.value(at: time) } ?? 0,
            opacity: sample.opacity
        )
        let presentation = ItemPresentation(
            box: box.size,
            anchor: box.anchor,
            values: values,
            motion: sample.animation.motion
        )
        let ownBox = Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            blend: sample.blend,
            reveal: sample.animation.reveal.rectangle(wiping: ownBox, from: sample.animation.revealFrom),
            content: content
        )
    }

    // An adjustment over its area, or over the whole list's frame without one: the output frame, or the unit when it is
    // parented. Its opacity blends the filtered result with what is below.
    private func adjustItem(
        of clip: ResolvedClip,
        filter: [ResolvedFilterOperation],
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> DisplayItem {
        let area = clip.area.map { space.area(of: $0, track: clip.track, at: time) }
        let covered = area ?? space.frame
        let presentation = ItemPresentation(area: covered, opacity: sample.opacity, motion: sample.animation.motion)

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            reveal: sample.animation.reveal.rectangle(wiping: covered, from: sample.animation.revealFrom),
            content: .adjust(AdjustItem(rectangle: area, filter: filter))
        )
    }
}
