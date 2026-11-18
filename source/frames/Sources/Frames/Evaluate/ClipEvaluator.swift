//
//  ClipEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Evaluates one clips entry at an instant into the items it draws, bottom first, in output pixels of its list: its
// keyframes sampled, its animation over its visible window combined on top, its blend, and its parent's map P(t)
// composed in through its space, after its tracked motion when it follows its parent's media (a media clip tracked in
// its own media moves its crop and masks instead, FRAMES-12). A title or media clip is drawn in its box's own pixels,
// its anchor point where that map carries its position, turned by its own rotation and the map's, at its own scale, and
// so is a shape given by `width` and `height`. A shape placed by its geometry is drawn in its space's coordinates,
// carried by that map whole, and an adjustment around its masks' bounding box so, or without a mask over the frame. Its
// masks are in the space it gives its children and are carried by that space's map.
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

    // The map from the space the clip gives its children to output pixels at the time: a title's text box, a media
    // clip's media pixels through its crop into its box, a box shape's box, and the space a shape's geometry or an
    // adjustment's mask is written in, each carried by the clip's transform, its tracked motion included.
    // Opacity and reveal take no part.
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
    // The items the clip draws, before its masks.
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

    // A title or media clip's item in its box's own pixels, wiped across `receiver`, what it draws there, from the
    // animation's side.
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

    // An adjustment over the whole list's frame, its reveal wiping across its masks' bounding box (FRAMES-14), or
    // across the frame without a mask. Its opacity mixes the filtered result with what is below, and its blend
    // composites the filtered result onto the unfiltered one.
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

    // An adjustment's mask is in the clip's space and carried by its tracked motion and P(t), and its animation acts
    // around the centre of its masks' bounding box (FRAMES-10). Without a mask the adjustment covers the list's frame,
    // in output pixels, and acts around its centre.
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

    // A clip's masks at the time on the space it gives its children (FRAMES-11). A title's and a media clip's are in
    // their own box or media, and so are a box shape's, which a tracked motion carries through their transform, and a
    // media clip tracked in its own media moves them there. A shape placed by its geometry and an adjustment write
    // theirs in their parent's space, each keyframe brought back to the instant when tracked, as their geometry is.
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

    // The bounding box of a clip's masks at the time in its own space, nil without a mask.
    private func maskBounds(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: Double
    ) -> Rectangle? {
        clip.mask.flatMap { space.masks(of: $0, track: clip.parentTrack, at: time).bounds }
    }
}
