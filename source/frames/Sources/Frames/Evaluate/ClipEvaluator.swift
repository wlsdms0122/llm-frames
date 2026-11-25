//
//  ClipEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Items come bottom first, in output pixels of the list the clip is drawn in. A clip that follows its parent's media
// takes that tracked motion before its parent's map; a media clip tracked in its own media moves its crop and masks
// instead. A clip with a corner pin is drawn as a group: one picture of a nested list holding what it draws flat in
// its box, carried onto its corner pin, with the tracked motion and its parent's map as its transform (FRAMES-20).
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
        at time: SampleTime
    ) -> [DisplayItem] {
        // A null draws nothing.
        guard case let .picture(content, composite) = clip.content else { return [] }

        if clip.cornerPin != nil {
            let group = self.group(
                of: clip,
                content: content,
                composite: composite,
                in: space,
                picture: picture,
                compositing: compositing,
                seed: seed,
                at: time
            )
            return group.map { [$0.cut(by: [], trackMatte: trackMatte)] } ?? []
        }

        let mask = masks(of: clip, in: space, at: time)

        return drawn(
            clip,
            content: content,
            composite: composite,
            in: space,
            picture: picture,
            compositing: compositing,
            seed: seed,
            at: time
        )
        .map { $0.cut(by: mask, trackMatte: trackMatte) }
    }

    // The map from the space the clip gives its children to output pixels: a title's box at the time, a media clip's
    // media pixels, a box shape's box, or the space a placed shape's geometry or an adjustment's mask is written in.
    // A clip with a corner pin gives the space its corner pin is written in, moved by its tracked motion and not by its
    // plane (FRAMES-10). A null gives the space a rect placed the same way gives. Opacity and reveal take no part.
    func childTransform(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: SampleTime
    ) -> AffineTransform {
        let sample = ClipSample(clip: clip, at: time)
        guard clip.cornerPin == nil else { return space.tracked(by: clip.parentTrack, at: time).transform }

        switch clip.content {
        case let .picture(.title(text), _):
            guard let box = clip.box else { return space.transform }

            let drawn = text.box(at: time)
            let size = Size(width: drawn.width, height: drawn.height)
            let transform = presentation(of: clip, box: box, size: size, sample: sample, in: space, at: time).transform
            return AffineTransform(translation: Point(x: drawn.x, y: drawn.y)).concatenating(transform)

        case let .picture(.media(media), _):
            guard let box = clip.box else { return space.transform }

            let transform = presentation(of: clip, box: box, size: box.size, sample: sample, in: space, at: time)
                .transform
            let crop = clip.crop(of: media, at: time)

            return AffineTransform(translation: Point(x: -crop.x, y: -crop.y))
                .concatenating(AffineTransform(
                    mapping: Size(width: crop.width, height: crop.height),
                    onto: Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)
                ))
                .concatenating(transform)

        case let .picture(.shape(shape), _):
            return shapeEvaluator.transform(of: shape, clip: clip, sample: sample, in: space, at: time)

        case .picture(.adjustment, _):
            let transform = adjustPresentation(of: clip, sample: sample, in: space, at: time).transform
            guard clip.composite?.mask == nil else { return transform }

            // Without a mask the adjustment acts in output pixels, and its children are still in its parent's space.
            return space.tracked(by: clip.parentTrack, at: time).transform.concatenating(transform)

        case let .null(null):
            return transform(of: null, clip: clip, sample: sample, in: space, at: time)
        }
    }

    // MARK: - Private
    private func drawn(
        _ clip: ResolvedClip,
        content: ResolvedPicture,
        composite: ResolvedComposite,
        in space: ClipSpace,
        picture: PictureItemSource?,
        compositing: Compositing,
        seed: Int,
        at time: SampleTime
    ) -> [DisplayItem] {
        let sample = ClipSample(clip: clip, at: time)

        switch content {
        case let .title(text):
            // A title carries its box.
            guard let box = clip.box else { return [] }

            // Its item lies in its text box, inside its box at the time.
            let glyphs = GlyphsItem(text: text, factor: sample.lengthFactor, at: time)
            let item = boxItem(
                of: clip,
                box: box,
                drawn: text.box(at: time),
                origin: text.textBoxInBox(at: time),
                sample: sample,
                composite: composite,
                in: space,
                content: .glyphs(glyphs),
                at: time
            ) { glyphs.drawnBounds(carriedBy: $0) }
            guard let schedule = sample.schedule, let units = text.units, !units.isEmpty else { return [item] }

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
                rectangle: clip.crop(of: media, at: time),
                destination: Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height),
                filter: FilterEntry.entries(of: media.filter, at: time),
                radius: media.appearance.radius.sampled(at: time, as: LookStructureTable.radius).cornerRadii ?? .zero,
                border: MediaBorder(
                    sampled: media.appearance.border.sampled(at: time, as: LookStructureTable.border),
                    factor: sample.lengthFactor,
                    isSample: time.sample.isSample
                ),
                shadow: DropShadow(
                    sampled: media.appearance.shadow.sampled(at: time, as: LookStructureTable.shadow),
                    factor: sample.lengthFactor,
                    carried: 1
                )
            )
            return [boxItem(
                of: clip,
                box: box,
                drawn: Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height),
                origin: .identity,
                sample: sample,
                composite: composite,
                in: space,
                content: .picture(item),
                at: time
            ) { item.receiverBox(carriedBy: $0) }]

        case let .shape(shape):
            return shapeEvaluator.items(of: shape, clip: clip, sample: sample, composite: composite, in: space, at: time)

        case let .adjustment(filter):
            return [adjustItem(of: clip, filter: filter, sample: sample, composite: composite, in: space, at: time)]
        }
    }

    // A clip with a corner pin drawn flat in its box B, `[0, 0, w, h]` at the time: its item as without a corner pin,
    // with the transform part of its animation about B's centre, opacity 1 and `normal` blend, its reveal, and its masks
    // in its own space, in a nested list of D, the box its reveal wipes, with B's top left at (-x, -y) for D at (x, y).
    // The group's `rect` is B in the list, its `dest` B and its corner pin Q(t), and it carries the clip's opacity, its
    // animation's included, and its blend. Where the corner pin draws nothing the group is nil, and in a sample list it
    // is there with four points at [0, 0] as its corner pin (FRAMES-20 Pictures). Nil for an adjustment, which takes no
    // corner pin. A title's item and its masks lie in its text box, inside B as inside its box at the time. A rect or an
    // ellipse is drawn in the box its `width` and `height` give at the time, its own masks in that box.
    private func group(
        of clip: ResolvedClip,
        content: ResolvedPicture,
        composite: ResolvedComposite,
        in space: ClipSpace,
        picture: PictureItemSource?,
        compositing: Compositing,
        seed: Int,
        at time: SampleTime
    ) -> DisplayItem? {
        let sample = ClipSample(clip: clip, at: time)
        // `origin` carries the content's own coordinates into B, and `ownSpace` the clip's own space into the content's
        // own coordinates, which are a title's own space and a shape's.
        let flat: (
            box: Rectangle,
            content: DisplayContent,
            origin: AffineTransform,
            receiver: (AffineTransform) -> Rectangle,
            ownSpace: AffineTransform
        )
        switch content {
        case let .title(text):
            let drawn = text.box(at: time)
            let glyphs = GlyphsItem(text: text, factor: sample.lengthFactor, at: time)
            flat = (
                Rectangle(x: 0, y: 0, width: drawn.width, height: drawn.height),
                .glyphs(glyphs),
                text.textBoxInBox(at: time),
                { glyphs.drawnBounds(carriedBy: $0) },
                .identity
            )

        case let .media(media):
            guard let picture, let size = clip.cornerPin?.size else { return nil }

            let box = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
            let item = PictureItem(
                source: picture,
                rectangle: clip.crop(of: media, at: time),
                destination: box,
                filter: FilterEntry.entries(of: media.filter, at: time),
                radius: media.appearance.radius.sampled(at: time, as: LookStructureTable.radius).cornerRadii ?? .zero,
                border: MediaBorder(
                    sampled: media.appearance.border.sampled(at: time, as: LookStructureTable.border),
                    factor: sample.lengthFactor,
                    isSample: time.sample.isSample
                ),
                shadow: DropShadow(
                    sampled: media.appearance.shadow.sampled(at: time, as: LookStructureTable.shadow),
                    factor: sample.lengthFactor,
                    carried: 1
                )
            )
            let crop = clip.crop(of: media, at: time)
            let cropMap = AffineTransform(translation: Point(x: -crop.x, y: -crop.y))
                .concatenating(AffineTransform(mapping: Size(width: crop.width, height: crop.height), onto: box))
            flat = (
                box,
                .picture(item),
                .identity,
                { Rectangle(bounding: $0.apply(toCornersOf: item.receiverBox(carriedBy: $0))) },
                cropMap
            )

        case let .shape(shape):
            let plane = { (box: Rectangle) in
                ItemPresentation(area: box, opacity: 1, motion: sample.animation.motion).transform
            }
            guard let drawn = shapeEvaluator.flat(shape, sample: sample, plane: plane, at: time) else { return nil }

            flat = (
                drawn.box,
                .path(drawn.path),
                .identity,
                { shapeEvaluator.receiverBox(of: drawn.path, carriedBy: $0) },
                .identity
            )

        case .adjustment:
            return nil
        }

        let box = Size(width: flat.box.width, height: flat.box.height)
        guard
            let cornerPin = clip.drawnCornerPin(box: box, areas: space.areas, clock: space.clock, at: time)
                ?? (time.sample.isSample ? Quad.collapsed : nil)
        else {
            return nil
        }

        let plane = ItemPresentation(
            area: flat.box,
            opacity: composite.opacity.opacity(at: time),
            motion: sample.animation.motion
        )
        let bounds = flat.receiver(flat.origin.concatenating(plane.transform))
        let transform = plane.transform.concatenating(AffineTransform(translation: Point(x: -bounds.x, y: -bounds.y)))
        let itemTransform = flat.origin.concatenating(transform)
        let list = ClipSpace(frame: Rectangle(x: 0, y: 0, width: bounds.width, height: bounds.height))
        let item = DisplayItem(
            transform: itemTransform,
            reveal: sample.animation.revealRectangle(wiping: flat.receiver(itemTransform)),
            content: flat.content,
            origin: ItemOrigin(clip: clip)
        )
        let mask = clip.ownMasks(at: time).map { mask in
            ItemMask(mask: mask, transform: flat.ownSpace.concatenating(itemTransform), factor: sample.lengthFactor)
        }
        var items = [item]
        if case let .picture(.title(text), _) = clip.content, case let .glyphs(glyphs) = flat.content, let schedule = sample.schedule,
           let units = text.units, !units.isEmpty {
            items = [group(
                of: clip,
                text: text,
                units: units,
                title: item,
                glyphs: glyphs,
                schedule: schedule,
                in: list,
                compositing: compositing,
                seed: seed,
                at: time
            )]
        }

        return DisplayItem(
            transform: space.tracked(by: clip.parentTrack, at: time).transform,
            opacity: plane.opacity,
            blend: composite.blend,
            content: .picture(PictureItem(
                source: .displayList(DisplayList(
                    size: Size(width: bounds.width, height: bounds.height),
                    background: .transparent,
                    compositing: compositing,
                    seed: seed,
                    items: items.map { $0.cut(by: mask, trackMatte: nil) }
                )),
                rectangle: Rectangle(x: -bounds.x, y: -bounds.y, width: box.width, height: box.height),
                destination: flat.box,
                cornerPin: cornerPin
            ))
        )
    }

    // A title animated by unit, drawn as one picture of a nested list the size of the list it is drawn in, which carries
    // the title's opacity and blend, and its masks and track matte once they cut it, so its units do not show through
    // each other. Inside, every item is in the title's text box and takes `title`'s transform: the background as it is,
    // and each unit's items, one for each layer in four passes, composed with the unit's motion about the unit's box. A
    // unit's reveal wipes what the unit draws, as a whole title's wipes what the title draws. The loop plays only while
    // every unit rests, so `title`'s reveal, the loop's, cuts every item in the title's text box.
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
        at time: SampleTime
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
                    drawing: UnitDrawing(layer: layer, index: index, box: box),
                    carrying: units[index].glyphs,
                    parts: parts,
                    extent: text.extent(of: index, at: time),
                    of: glyphs,
                    factor: factor
                )
            }
            let reveal = reveal(
                of: sample.revealRectangle(wiping: layers[0].drawnBounds(carriedBy: presentation.transform)),
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
            content: .glyphs(GlyphsItem(
                size: glyphs.size,
                writingMode: glyphs.writingMode,
                runs: [],
                extent: glyphs.extent,
                background: glyphs.background
            )),
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

    // A unit's reveal and the loop's are in the title's text box, and a unit shows where both show.
    private func reveal(
        of unit: Rectangle?,
        within loop: Rectangle?
    ) -> Rectangle? {
        guard let unit, let loop else { return unit ?? loop }

        return unit.intersection(loop) ?? Rectangle(x: unit.x, y: unit.y, width: 0, height: 0)
    }

    // `drawn` is the clip's box at the time, in its box at its placed size, `origin` the map from the item's own
    // coordinates into the box at the time, and `receiver` what the item draws in its own coordinates under the item's transform, which
    // the reveal wipes across.
    private func boxItem(
        of clip: ResolvedClip,
        box: ResolvedBox,
        drawn: Rectangle,
        origin: AffineTransform,
        sample: ClipSample,
        composite: ResolvedComposite,
        in space: ClipSpace,
        content: DisplayContent,
        at time: SampleTime,
        receiver: (AffineTransform) -> Rectangle
    ) -> DisplayItem {
        let size = Size(width: drawn.width, height: drawn.height)
        let presentation = presentation(of: clip, box: box, size: size, sample: sample, in: space, at: time)
        let transform = origin
            .concatenating(AffineTransform(translation: Point(x: drawn.x, y: drawn.y)))
            .concatenating(presentation.transform)

        return DisplayItem(
            transform: transform,
            opacity: presentation.opacity * composite.opacity.opacity(at: time),
            blend: composite.blend,
            reveal: sample.animation.revealRectangle(wiping: receiver(transform)),
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
        at time: SampleTime
    ) -> ItemPresentation {
        let tracked = space.tracked(by: clip.parentTrack, at: time)
        let anchor = tracked.transform.apply(to: space.anchor(of: box, track: clip.parentTrack, at: time))
        let values = KeyframedValues(
            position: Point(x: anchor.x - box.anchor.x, y: anchor.y - box.anchor.y),
            scale: clip.scale.map { $0.value(at: time) } ?? .identity,
            rotation: (clip.rotation.map { $0.value(at: time) } ?? 0) + tracked.transform.rotation
        )

        return ItemPresentation(box: size, anchor: box.anchor, values: values, motion: sample.animation.motion)
    }

    // Its opacity mixes the filtered result with what is below, and its blend composites the filtered result onto the
    // unfiltered one. Its reveal wipes across what it draws, the list's frame in its own coordinates cut to what its
    // masks let through, and where its transform flattens the plane it draws nothing, whatever the box.
    private func adjustItem(
        of clip: ResolvedClip,
        filter: TimedValue,
        sample: ClipSample,
        composite: ResolvedComposite,
        in space: ClipSpace,
        at time: SampleTime
    ) -> DisplayItem {
        let presentation = adjustPresentation(of: clip, sample: sample, in: space, at: time)
        let adjust = AdjustItem(filter: FilterEntry.entries(of: filter, at: time))
        let receiver = adjust.drawnBounds(
            carriedBy: presentation.transform,
            masks: masks(of: clip, in: space, at: time),
            over: space.frame
        ) ?? space.frame

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity * composite.opacity.opacity(at: time),
            blend: composite.blend,
            reveal: sample.animation.revealRectangle(wiping: receiver),
            content: .adjust(adjust)
        )
    }

    // The animation acts about the centre of the masks' bounding box, or of the list's frame without a mask. The
    // opacity is the animation's, which the clip's own multiplies where it is drawn.
    private func adjustPresentation(
        of clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: SampleTime
    ) -> ItemPresentation {
        guard let bounds = maskBounds(of: clip, in: space, at: time) else {
            return ItemPresentation(area: space.frame, opacity: 1, motion: sample.animation.motion)
        }

        return ItemPresentation(
            area: bounds,
            opacity: 1,
            motion: sample.animation.motion,
            carriedBy: space.tracked(by: clip.parentTrack, at: time).transform
        )
    }

    // The map from the space a null gives its children to output pixels, which is a rect's placed the same way: by its
    // box, `width` by `height` at the time with its anchor point at the same fraction of it, or by its area, about its
    // anchor point. A null placed by its box carries it in its entry.
    private func transform(
        of null: ResolvedNull,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: SampleTime
    ) -> AffineTransform {
        let tracked = space.tracked(by: clip.parentTrack, at: time)
        switch null.geometry {
        case let .box(width, height):
            guard let box = clip.box else { return tracked.transform }

            let size = Size(width: width.value(at: time), height: height.value(at: time))
            let anchor = Point(
                x: box.size.width > 0 ? box.anchor.x * size.width / box.size.width : 0,
                y: box.size.height > 0 ? box.anchor.y * size.height / box.size.height : 0
            )
            let sized = ResolvedBox(size: size, position: box.position, anchor: anchor)
            return presentation(of: clip, box: sized, size: size, sample: sample, in: space, at: time).transform

        case let .area(area, placement):
            let bounds = space.area(of: area, track: clip.parentTrack, at: time)
            let motion = sample.animation.motion
            return AffineTransform(
                placing: bounds,
                anchor: placement.anchor,
                position: placement.position.map { space.point(of: $0, track: clip.parentTrack, at: time) },
                scale: sample.ownScale,
                rotation: (clip.rotation.map { $0.value(at: time) } ?? 0) + motion.value(of: .rotation),
                moved: Point(x: motion.value(of: .x) * bounds.width, y: motion.value(of: .y) * bounds.height)
            ).concatenating(tracked.transform)
        }
    }

    // A placed shape and an adjustment write their masks in their parent's space, a title in its text box, which lies
    // inside the box its children see, and any other clip in its own box or media pixels.
    private func masks(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: SampleTime
    ) -> [ItemMask] {
        guard let mask = clip.composite?.mask else { return [] }

        let masks = clip.space == .parent
            ? space.masks(of: mask, track: clip.parentTrack, at: time)
            : clip.ownMasks(at: time)
        let inBox = if case let .picture(.title(text), _) = clip.content {
            text.textBoxInBox(at: time)
        } else {
            AffineTransform.identity
        }
        let transform = inBox
            .concatenating(clip.ownMotion(at: time))
            .concatenating(childTransform(of: clip, in: space, at: time))
        let factor = ClipSample(clip: clip, at: time).lengthFactor
        return masks.map { ItemMask(mask: $0, transform: transform, factor: factor) }
    }

    private func maskBounds(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: SampleTime
    ) -> Rectangle? {
        clip.composite?.mask.flatMap { space.masks(of: $0, track: clip.parentTrack, at: time).bounds }
    }
}
