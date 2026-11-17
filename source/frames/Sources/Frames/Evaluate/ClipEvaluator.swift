//
//  ClipEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Evaluates one clips entry at an instant into the items it draws, bottom first, in output pixels of its list: its
// keyframes sampled, its animation over its visible window combined on top, its blend, and its parent's map P(t)
// composed in through its space, after its tracked motion when it is tracked. A title or media clip is drawn in its
// box's own pixels, its anchor point where that map carries its position, turned by its own rotation and the map's, at
// its own scale. A shape or adjustment is drawn in its space's coordinates on its area, carried by that map whole, or
// without an area over the frame.
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

    // The map from the space the clip gives its children to output pixels at the time: a title's text box, a media
    // clip's media pixels through its crop into its box, and the space a shape's or adjustment's area is written in,
    // each carried by the clip's transform, its tracked motion included. Opacity and reveal take no part.
    func childTransform(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: Double
    ) -> AffineTransform {
        let sample = ClipSample(clip: clip, at: time)

        switch clip.content {
        case .title:
            guard let box = clip.box else { return space.transform }

            return presentation(of: clip, box: box, sample: sample, in: space, at: time).transform

        case .media:
            guard let box = clip.box else { return space.transform }

            let transform = presentation(of: clip, box: box, sample: sample, in: space, at: time).transform
            guard let crop = clip.crop?.value(at: time).rectangle else { return transform }

            return AffineTransform(translation: Point(x: -crop.x, y: -crop.y))
                .concatenating(AffineTransform(
                    mapping: Size(width: crop.width, height: crop.height),
                    onto: Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)
                ))
                .concatenating(transform)

        case let .shape(drawing):
            return shapeEvaluator.transform(of: drawing, clip: clip, sample: sample, in: space, at: time)

        case .adjustment:
            let transform = adjustPresentation(of: clip, sample: sample, in: space, at: time).transform
            guard clip.area == nil else { return transform }

            // Without an area the adjustment acts in output pixels, and its children are still in its parent's space.
            return space.tracked(by: clip.track, at: time).transform.concatenating(transform)
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
        let presentation = presentation(of: clip, box: box, sample: sample, in: space, at: time)
        let ownBox = Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            blend: sample.blend,
            reveal: sample.animation.reveal.rectangle(wiping: ownBox, from: sample.animation.revealFrom),
            content: content
        )
    }

    // The box keeps its size in output pixels under a parent and its tracked motion: its anchor point goes where they
    // carry it, and it turns by their rotation on top of its own.
    private func presentation(
        of clip: ResolvedClip,
        box: ResolvedBox,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> ItemPresentation {
        let tracked = space.tracked(by: clip.track, at: time)
        let anchor = tracked.transform.apply(to: space.anchor(of: box, track: clip.track, at: time))
        let values = KeyframedValues(
            position: Point(x: anchor.x - box.anchor.x, y: anchor.y - box.anchor.y),
            scale: clip.scale.map { $0.value(at: time) } ?? 1,
            rotation: (clip.rotation.map { $0.value(at: time) } ?? 0) + tracked.rotation,
            opacity: sample.opacity
        )

        return ItemPresentation(box: box.size, anchor: box.anchor, values: values, motion: sample.animation.motion)
    }

    // An adjustment over its area, or over the whole list's frame without one. Its opacity blends the filtered result
    // with what is below.
    private func adjustItem(
        of clip: ResolvedClip,
        filter: [ResolvedFilterOperation],
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> DisplayItem {
        let area = clip.area.map { space.area(of: $0, track: clip.track, at: time) }
        let presentation = adjustPresentation(of: clip, sample: sample, in: space, at: time)

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            reveal: sample.animation.reveal.rectangle(wiping: area ?? space.frame, from: sample.animation.revealFrom),
            content: .adjust(AdjustItem(rectangle: area, filter: filter))
        )
    }

    // An area is in the clip's space and carried by its tracked motion and P(t). Without one the adjustment covers the
    // list's frame, in output pixels.
    private func adjustPresentation(
        of clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> ItemPresentation {
        guard let area = clip.area.map({ space.area(of: $0, track: clip.track, at: time) }) else {
            return ItemPresentation(area: space.frame, opacity: sample.opacity, motion: sample.animation.motion)
        }

        return ItemPresentation(
            area: area,
            opacity: sample.opacity,
            motion: sample.animation.motion,
            carriedBy: space.tracked(by: clip.track, at: time).transform
        )
    }
}
