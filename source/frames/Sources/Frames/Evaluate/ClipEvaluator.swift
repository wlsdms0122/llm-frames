//
//  ClipEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Items come bottom first, in output pixels of the list the clip is drawn in. A clip that follows its parent's media
// takes that tracked motion before its parent's map; a media clip tracked in its own media moves its crop and masks
// instead.
struct ClipEvaluator: Sendable {
    // MARK: - Property
    private let shapeEvaluator = ShapeEvaluator()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `picture` is a media clip's picture at the time, and nil for any other clip. `trackMatte` is the clip's track
    // matte at the time, which cuts its items after its masks.
    func items(
        of clip: ResolvedClip,
        in space: ClipSpace,
        picture: PictureItemSource?,
        trackMatte: ItemTrackMatte?,
        at time: Double
    ) -> [DisplayItem] {
        let mask = masks(of: clip, in: space, at: time)

        return drawn(clip, in: space, picture: picture, at: time).map { $0.cut(by: mask, trackMatte: trackMatte) }
    }

    // The map from the space the clip gives its children to output pixels: a title's text box, a media clip's media
    // pixels, a box shape's box, or the space a placed shape's geometry or an adjustment's mask is written in. Opacity
    // and reveal take no part.
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
            guard let crop = clip.crop(at: time) else { return transform }

            return AffineTransform(translation: Point(x: -crop.x, y: -crop.y))
                .concatenating(AffineTransform(
                    mapping: Size(width: crop.width, height: crop.height),
                    onto: Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)
                ))
                .concatenating(transform)

        case let .shape(shape):
            return shapeEvaluator.transform(of: shape, clip: clip, sample: sample, in: space, at: time)

        case .adjustment:
            let transform = adjustPresentation(of: clip, sample: sample, in: space, at: time).transform
            guard clip.mask == nil else { return transform }

            // Without a mask the adjustment acts in output pixels, and its children are still in its parent's space.
            return space.tracked(by: clip.parentTrack, at: time).transform.concatenating(transform)
        }
    }

    // MARK: - Private
    private func drawn(
        _ clip: ResolvedClip,
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
            return [boxItem(
                of: clip,
                box: box,
                receiver: glyphs.drawnBounds(),
                sample: sample,
                in: space,
                content: .glyphs(glyphs),
                at: time
            )]

        case let .media(media):
            // A media clip carries its box and every crop conformed to it, and its picture is given.
            guard let box = clip.box, let picture else { return [] }

            let item = PictureItem(
                source: picture,
                rectangle: clip.crop(at: time),
                destination: Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height),
                filter: media.filter,
                radius: media.appearance.radius,
                border: media.appearance.border,
                shadow: media.appearance.shadow
            )
            // The border lies inside the box, so only the shadow reaches past it.
            let receiver = item.shadow.map { item.destination.union($0.castBounds(of: item.destination)) }
            return [boxItem(
                of: clip,
                box: box,
                receiver: receiver ?? item.destination,
                sample: sample,
                in: space,
                content: .picture(item),
                at: time
            )]

        case let .shape(shape):
            return shapeEvaluator.items(of: shape, clip: clip, sample: sample, in: space, at: time)

        case let .adjustment(filter):
            return [adjustItem(of: clip, filter: filter, sample: sample, in: space, at: time)]
        }
    }

    // `receiver` is what the item draws in its box's own pixels, which the reveal wipes across.
    private func boxItem(
        of clip: ResolvedClip,
        box: ResolvedBox,
        receiver: Rectangle,
        sample: ClipSample,
        in space: ClipSpace,
        content: DisplayContent,
        at time: Double
    ) -> DisplayItem {
        let presentation = presentation(of: clip, box: box, sample: sample, in: space, at: time)

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            blend: sample.blend,
            reveal: sample.animation.reveal.rectangle(wiping: receiver, from: sample.animation.revealFrom),
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
        let tracked = space.tracked(by: clip.parentTrack, at: time)
        let anchor = tracked.transform.apply(to: space.anchor(of: box, track: clip.parentTrack, at: time))
        let values = KeyframedValues(
            position: Point(x: anchor.x - box.anchor.x, y: anchor.y - box.anchor.y),
            scale: clip.scale.map { $0.value(at: time) } ?? 1,
            rotation: (clip.rotation.map { $0.value(at: time) } ?? 0) + tracked.rotation,
            opacity: sample.opacity
        )

        return ItemPresentation(box: box.size, anchor: box.anchor, values: values, motion: sample.animation.motion)
    }

    // Its opacity mixes the filtered result with what is below, and its blend composites the filtered result onto the
    // unfiltered one.
    private func adjustItem(
        of clip: ResolvedClip,
        filter: [ResolvedFilterOperation],
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> DisplayItem {
        let bounds = maskBounds(of: clip, in: space, at: time)
        let presentation = adjustPresentation(of: clip, sample: sample, in: space, at: time)

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            blend: sample.blend,
            reveal: sample.animation.reveal.rectangle(wiping: bounds ?? space.frame, from: sample.animation.revealFrom),
            content: .adjust(AdjustItem(filter: filter))
        )
    }

    // The animation acts about the centre of the masks' bounding box, or of the list's frame without a mask.
    private func adjustPresentation(
        of clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> ItemPresentation {
        guard let bounds = maskBounds(of: clip, in: space, at: time) else {
            return ItemPresentation(area: space.frame, opacity: sample.opacity, motion: sample.animation.motion)
        }

        return ItemPresentation(
            area: bounds,
            opacity: sample.opacity,
            motion: sample.animation.motion,
            carriedBy: space.tracked(by: clip.parentTrack, at: time).transform
        )
    }

    // A placed shape and an adjustment write their masks in their parent's space, and any other clip in its own box or
    // media pixels.
    private func masks(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: Double
    ) -> [ItemMask] {
        guard let mask = clip.mask else { return [] }

        let masks = clip.space == .parent
            ? space.masks(of: mask, track: clip.parentTrack, at: time)
            : clip.ownMasks(at: time)
        let transform = clip.ownMotion(at: time).concatenating(childTransform(of: clip, in: space, at: time))
        let scale = ClipSample(clip: clip, at: time).ownScale
        return masks.map { ItemMask(mask: $0, transform: transform, scale: scale) }
    }

    private func maskBounds(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: Double
    ) -> Rectangle? {
        clip.mask.flatMap { space.masks(of: $0, track: clip.parentTrack, at: time).bounds }
    }
}
