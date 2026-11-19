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
    // matte at the time, which cuts its items after its masks. `seed` is the seed of the list the items are drawn in,
    // which a list nested for a title's units takes.
    func items(
        of clip: ResolvedClip,
        in space: ClipSpace,
        picture: PictureItemSource?,
        trackMatte: ItemTrackMatte?,
        compositing: Compositing,
        seed: Int,
        at time: Double
    ) -> [DisplayItem] {
        let mask = masks(of: clip, in: space, at: time)

        return drawn(clip, in: space, picture: picture, compositing: compositing, seed: seed, at: time)
            .map { $0.cut(by: mask, trackMatte: trackMatte) }
    }

    // The map from the space the clip gives its children to output pixels: a title's box at the time, a media clip's
    // media pixels, a box shape's box, or the space a placed shape's geometry or an adjustment's mask is written in.
    // Opacity and reveal take no part.
    func childTransform(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: Double
    ) -> AffineTransform {
        let sample = ClipSample(clip: clip, at: time)

        switch clip.content {
        case let .title(text):
            guard let box = clip.box else { return space.transform }

            let drawn = text.box(at: time)
            let size = Size(width: drawn.width, height: drawn.height)
            let transform = presentation(of: clip, box: box, size: size, sample: sample, in: space, at: time).transform
            return AffineTransform(translation: Point(x: drawn.x, y: drawn.y)).concatenating(transform)

        case .media:
            guard let box = clip.box else { return space.transform }

            let transform = presentation(of: clip, box: box, size: box.size, sample: sample, in: space, at: time)
                .transform
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
        compositing: Compositing,
        seed: Int,
        at time: Double
    ) -> [DisplayItem] {
        let sample = ClipSample(clip: clip, at: time)

        switch clip.content {
        case let .title(text):
            // A title carries its box.
            guard let box = clip.box else { return [] }

            let glyphs = GlyphsItem(text: text, factor: sample.lengthFactor, at: time)
            let item = boxItem(
                of: clip,
                box: box,
                drawn: text.box(at: time),
                sample: sample,
                in: space,
                content: .glyphs(glyphs),
                at: time
            ) { glyphs.drawnBounds(carriedBy: $0) }
            guard let schedule = sample.schedule, let units = text.units else { return [item] }

            return [group(
                of: clip,
                text: text,
                units: units,
                title: item,
                glyphs: glyphs,
                schedule: schedule,
                in: space,
                compositing: compositing,
                seed: seed,
                at: time
            )]

        case let .media(media):
            // A media clip carries its box and every crop conformed to it, and its picture is given.
            guard let box = clip.box, let picture else { return [] }

            let item = PictureItem(
                source: picture,
                rectangle: clip.crop(at: time),
                destination: Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height),
                filter: FilterEntry.entries(of: media.filter, at: time),
                radius: media.appearance.radius.sampled(at: time, as: LookStructureTable.length).number ?? 0,
                border: MediaBorder(
                    sampled: media.appearance.border.sampled(at: time, as: LookStructureTable.border),
                    factor: sample.lengthFactor
                ),
                shadow: DropShadow(
                    sampled: media.appearance.shadow.sampled(at: time, as: LookStructureTable.shadow),
                    factor: sample.lengthFactor,
                    carried: 1
                )
            )
            // The border lies inside the box, so only the shadow reaches past it.
            let receiver = item.shadow.map { item.destination.union($0.castBounds(of: item.destination)) }
            return [boxItem(
                of: clip,
                box: box,
                drawn: Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height),
                sample: sample,
                in: space,
                content: .picture(item),
                at: time
            ) { _ in receiver ?? item.destination }]

        case let .shape(shape):
            return shapeEvaluator.items(of: shape, clip: clip, sample: sample, in: space, at: time)

        case let .adjustment(filter):
            return [adjustItem(of: clip, filter: filter, sample: sample, in: space, at: time)]
        }
    }

    // A title animated by unit, drawn as one picture of a nested list the size of the list it is drawn in, which carries
    // the title's opacity and blend, and its masks and track matte once they cut it, so its units do not show through
    // each other. Inside, every item is in `title`'s box and takes its transform: the background as it is, and each
    // unit's items, one for each layer in four passes, composed with the unit's motion about the unit's box. A unit's
    // reveal wipes what the unit draws, as a whole title's wipes what the title draws. The loop plays only while every
    // unit rests, so `title`'s reveal, the loop's, cuts every item in the title's box.
    private func group(
        of clip: ResolvedClip,
        text: ResolvedText,
        units: [PlacedUnit],
        title item: DisplayItem,
        glyphs: GlyphsItem,
        schedule: UnitSchedule,
        in space: ClipSpace,
        compositing: Compositing,
        seed: Int,
        at time: Double
    ) -> DisplayItem {
        let origin = ItemOrigin(clip: clip)
        let sampler = UnitSampler()
        let unitItems = units.indices.map { index in
            let box = text.unitBox(of: index, at: time)
            let sample = sampler.unit(index, of: clip.animation, schedule: schedule, at: time)
            let presentation = ItemPresentation(area: box, opacity: 1, motion: sample.motion, carriedBy: item.transform)
            let factor = Scale(sample.motion.value(of: .scale)).factor
            let parts = text.parts(of: index, at: time)
            let layers = GlyphLayer.allCases.map { layer in
                GlyphsItem(
                    carrying: units[index].glyphs,
                    parts: parts,
                    in: box,
                    glyphBox: text.glyphBox(of: index, at: time),
                    of: glyphs,
                    layer: layer,
                    factor: factor
                )
            }
            let reveal = reveal(
                of: sample.reveal.rectangle(
                    wiping: layers[0].drawnBounds(carriedBy: presentation.transform),
                    from: sample.revealFrom
                ),
                within: item.reveal
            )

            return layers.map { layer in
                DisplayItem(
                    transform: presentation.transform,
                    opacity: presentation.opacity,
                    reveal: reveal,
                    content: .glyphs(layer),
                    origin: origin
                )
            }
        }
        let background = DisplayItem(
            transform: item.transform,
            reveal: item.reveal,
            content: .glyphs(GlyphsItem(size: glyphs.size, runs: [], background: glyphs.background)),
            origin: origin
        )
        let passes = GlyphLayer.allCases.indices.flatMap { layer in unitItems.map { $0[layer] } }
        let list = DisplayList(
            size: Size(width: space.frame.width, height: space.frame.height),
            background: .transparent,
            compositing: compositing,
            seed: seed,
            items: [background] + passes
        )

        return DisplayItem(
            opacity: item.opacity,
            blend: item.blend,
            content: .picture(PictureItem(source: .displayList(list), rectangle: space.frame, destination: space.frame))
        )
    }

    // A unit's reveal and the loop's are in the title's box, and a unit shows where both show.
    private func reveal(
        of unit: Rectangle?,
        within loop: Rectangle?
    ) -> Rectangle? {
        guard let unit, let loop else { return unit ?? loop }

        return unit.intersection(loop) ?? Rectangle(x: unit.x, y: unit.y, width: 0, height: 0)
    }

    // `drawn` is the item's own box at the time, in the clip's box at its placed size, and `receiver` what the item
    // draws in its own pixels under the item's transform, which the reveal wipes across.
    private func boxItem(
        of clip: ResolvedClip,
        box: ResolvedBox,
        drawn: Rectangle,
        sample: ClipSample,
        in space: ClipSpace,
        content: DisplayContent,
        at time: Double,
        receiver: (AffineTransform) -> Rectangle
    ) -> DisplayItem {
        let size = Size(width: drawn.width, height: drawn.height)
        let presentation = presentation(of: clip, box: box, size: size, sample: sample, in: space, at: time)
        let transform = AffineTransform(translation: Point(x: drawn.x, y: drawn.y))
            .concatenating(presentation.transform)

        return DisplayItem(
            transform: transform,
            opacity: presentation.opacity,
            blend: sample.blend,
            reveal: sample.animation.reveal.rectangle(wiping: receiver(transform), from: sample.animation.revealFrom),
            content: content
        )
    }

    // The box keeps its size in output pixels under a parent and its tracked motion: its anchor point goes where they
    // carry it, and it turns by their map's rotation on top of its own, never mirrored. `size` is the box's size at the
    // time, which the animation's offset is in multiples of. A title's anchor point stays where resolve placed it while
    // its box changes, so scale and rotation act about it.
    private func presentation(
        of clip: ResolvedClip,
        box: ResolvedBox,
        size: Size,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> ItemPresentation {
        let tracked = space.tracked(by: clip.parentTrack, at: time)
        let anchor = tracked.transform.apply(to: space.anchor(of: box, track: clip.parentTrack, at: time))
        let values = KeyframedValues(
            position: Point(x: anchor.x - box.anchor.x, y: anchor.y - box.anchor.y),
            scale: clip.scale.map { $0.value(at: time) } ?? .identity,
            rotation: (clip.rotation.map { $0.value(at: time) } ?? 0) + tracked.transform.rotation,
            opacity: sample.opacity
        )

        return ItemPresentation(box: size, anchor: box.anchor, values: values, motion: sample.animation.motion)
    }

    // Its opacity mixes the filtered result with what is below, and its blend composites the filtered result onto the
    // unfiltered one.
    private func adjustItem(
        of clip: ResolvedClip,
        filter: TimedValue,
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
            content: .adjust(AdjustItem(filter: FilterEntry.entries(of: filter, at: time)))
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
        let factor = ClipSample(clip: clip, at: time).lengthFactor
        return masks.map { ItemMask(mask: $0, transform: transform, factor: factor) }
    }

    private func maskBounds(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: Double
    ) -> Rectangle? {
        clip.mask.flatMap { space.masks(of: $0, track: clip.parentTrack, at: time).bounds }
    }
}
