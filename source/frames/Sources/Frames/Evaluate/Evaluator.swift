//
//  Evaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Lists nested in a display list, for storyline pictures, compound clips and track mattes, carry its seed, and a
// storyline picture's and a track matte's a transparent background, so what such a list leaves uncovered shows what
// lies below its picture. A clip used as a track matte draws no item of its own, and its children are drawn as usual.
// The outermost list carries the sequence's colour space and peak, and every list the compositing of the sequence
// whose items it holds, a compound clip's or a template instance's its own. An HDR picture is tone mapped to
// `targetPeak`, the outermost sequence's peak, where its clip's `toneMap` is true, and a transition cover's always is.
// A transition matte is read as an analysis picture.
package struct Evaluator: Sendable {
    // MARK: - Property
    private let clipEvaluator = ClipEvaluator()
    private let seeder = GrainSeeder()
    private let transitionSampler = TransitionSampler()
    private let targetPeak: Double

    // MARK: - Initializer
    package init() {
        self.init(targetPeak: ColorSpace.srgb.peakLuminance)
    }

    private init(targetPeak: Double) {
        self.targetPeak = targetPeak
    }

    // MARK: - Public
    package func displayList(
        of sequence: ResolvedSequence,
        at time: Double
    ) -> DisplayList {
        let format = sequence.format

        return Evaluator(targetPeak: format.peakLuminance).displayList(
            of: sequence,
            at: time,
            seed: seeder.seed(at: time, fps: format.fps),
            colorSpace: format.colorSpace,
            peak: format.peak
        )
    }

    // MARK: - Private
    private func displayList(
        of sequence: ResolvedSequence,
        at time: Double,
        seed: Int,
        colorSpace: ColorSpace?,
        peak: Double? = nil
    ) -> DisplayList {
        let format = sequence.format
        let transition = ActiveTransition(storyline: sequence.storyline, at: time)
        let parents = ParentEvaluator(sequence: sequence)
        let items = clipItems(of: sequence, parents: parents, side: .below, at: time, seed: seed)
            + storylineItems(of: sequence, parents: parents, transition: transition, at: time, seed: seed)
            + coverItems(of: transition, in: format.frame, at: time)
            + clipItems(of: sequence, parents: parents, side: .above, at: time, seed: seed)

        return DisplayList(
            size: format.size,
            background: format.background,
            colorSpace: colorSpace,
            peak: peak,
            compositing: format.compositing,
            seed: seed,
            items: items
        )
    }

    private func clipItems(
        of sequence: ResolvedSequence,
        parents: ParentEvaluator,
        side: LaneSide,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        sequence.clips.enumerated()
            .filter { _, clip in
                // Resolution sets every clip's lane.
                let lane = clip.lane ?? 1
                return (side == .below ? lane < 0 : lane > 0)
                    && TimeRange(start: clip.start, end: clip.end).contains(time)
                    && !sequence.isMatte(clip)
            }
            .sorted { left, right in
                (left.element.lane ?? 1, left.offset) < (right.element.lane ?? 1, right.offset)
            }
            .flatMap { _, clip in
                let trackMatte = trackMatte(clip.trackMatte, in: sequence, parents: parents, at: time, seed: seed)
                return items(
                    of: clip,
                    parents: parents,
                    trackMatte: trackMatte,
                    compositing: sequence.format.compositing,
                    at: time,
                    seed: seed
                )
            }
    }

    private func items(
        of clip: ResolvedClip,
        parents: ParentEvaluator,
        trackMatte: ItemTrackMatte?,
        compositing: Compositing,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        let space = parents.space(of: clip, at: time)
        let picture = picture(of: clip, at: time, seed: seed)
        let origin = ItemOrigin(clip: clip)

        return clipEvaluator.items(
            of: clip,
            in: space,
            picture: picture,
            trackMatte: trackMatte,
            compositing: compositing,
            seed: seed,
            at: time
        )
        .map { $0.drawn(by: origin) }
    }

    // A matte's source list is the size of the list the matted item sits in; `DisplayListReader` rejects any other.
    private func trackMatte(
        _ trackMatte: TrackMatte?,
        in sequence: ResolvedSequence,
        parents: ParentEvaluator,
        at time: Double,
        seed: Int
    ) -> ItemTrackMatte? {
        sequence.matteChain(from: trackMatte).reversed().reduce(ItemTrackMatte?.none) { inner, link in
            let items = TimeRange(start: link.clip.start, end: link.clip.end).contains(time)
                ? self.items(
                    of: link.clip,
                    parents: parents,
                    trackMatte: inner,
                    compositing: sequence.format.compositing,
                    at: time,
                    seed: seed
                )
                : []
            let source = DisplayList(
                size: sequence.format.size,
                background: .transparent,
                compositing: sequence.format.compositing,
                seed: seed,
                items: items.map { $0.normallyBlended() }
            )

            return ItemTrackMatte(source: source, mode: link.trackMatte.mode, isInverted: link.trackMatte.isInverted)
        }
    }

    // A still has no clock and shows media time 0.
    private func picture(
        of clip: ResolvedClip,
        at time: Double,
        seed: Int
    ) -> PictureItemSource? {
        guard case let .media(media) = clip.content else { return nil }

        return source(
            of: media.media,
            colorSpace: media.colorSpace,
            isToneMapped: media.isToneMapped,
            at: media.clock?.mediaTime(atSequenceTime: time) ?? 0,
            seed: seed
        )
    }

    // Out of a transition the entries' ranges are their edit ranges, so at most one holds the time.
    private func storylineItems(
        of sequence: ResolvedSequence,
        parents: ParentEvaluator,
        transition: ActiveTransition?,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        guard let transition else {
            let storyline = sequence.storyline
            return storyline.indices
                .filter { TimeRange(start: storyline[$0].start, end: storyline[$0].end).contains(time) }
                .map { index in
                    storylineItem(of: index, in: sequence, parents: parents, matte: nil, at: time, seed: seed)
                }
        }

        let progress = transitionSampler.progress(through: transition.range, at: time)
        let spans = transition.transition
        return spans.over.bottomFirst.map { order in
            switch order {
            case .incoming:
                storylineItem(
                    of: transition.incoming,
                    in: sequence,
                    parents: parents,
                    matte: spans.matte.map { matte(of: $0, at: progress) },
                    at: time,
                    seed: seed
                )

            case .outgoing:
                storylineItem(
                    of: transition.outgoing,
                    in: sequence,
                    parents: parents,
                    matte: nil,
                    at: time,
                    seed: seed
                )
            }
        }
    }

    // A storyline picture is two items. The inner one carries the clip's own transform, opacity, masks and track matte
    // inside a nested list the size of the frame; the outer one draws that list and carries the blend, the transition
    // motion and the matte, so the transition motion acts on everything inside it. For a clip with a corner pin the
    // inner item is its group at opacity 1, and the outer one carries the clip's opacity (FRAMES-27).
    private func storylineItem(
        of index: Int,
        in sequence: ResolvedSequence,
        parents: ParentEvaluator,
        matte: PictureMatte?,
        at time: Double,
        seed: Int
    ) -> DisplayItem {
        let frame = sequence.format.frame
        let entry = sequence.storyline[index]
        let trackMatte = trackMatte(entry.trackMatte, in: sequence, parents: parents, at: time, seed: seed)
        let items = innerItems(
            of: entry,
            trackMatte: trackMatte,
            compositing: sequence.format.compositing,
            at: time,
            seed: seed
        )
        let list = DisplayList(
            size: sequence.format.size,
            background: .transparent,
            compositing: sequence.format.compositing,
            seed: seed,
            items: items
        )
        let picture = PictureItem(source: .displayList(list), rectangle: frame, destination: frame, matte: matte)
        let sample = transitionSampler.motion(of: index, in: sequence.storyline, at: time)
        let opacity = entry.cornerPin == nil ? 1 : entry.opacity.opacity(at: time)
        let presentation = ItemPresentation(area: frame, opacity: opacity, motion: sample.motion)

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            blend: entry.blend,
            reveal: sample.reveal.rectangle(wiping: frame, from: sample.revealFrom),
            content: .picture(picture),
            origin: ItemOrigin(entry: entry)
        )
    }

    private func innerItems(
        of entry: ResolvedStorylineClip,
        trackMatte: ItemTrackMatte?,
        compositing: Compositing,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        if let cornerPin = entry.cornerPin {
            let group = group(
                of: entry,
                cornerPin: cornerPin,
                trackMatte: trackMatte,
                compositing: compositing,
                at: time,
                seed: seed
            )
            return group.map { [$0] } ?? []
        }
        guard let size = entry.box?.size, let scale = entry.scale else { return [] }

        let origin = ItemOrigin(entry: entry)
        let box = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let presentation = entry.presentation(at: time)
        // A box's own pixels are carried at the entry's scale, so a carried length is written as it is.
        let factor = scale.value(at: time).factor
        let content: DisplayContent
        if let media = entry.media {
            content = .picture(PictureItem(
                source: source(
                    of: media,
                    colorSpace: entry.colorSpace,
                    isToneMapped: entry.isToneMapped,
                    at: entry.mediaTime(at: time),
                    seed: seed
                ),
                rectangle: entry.crop(at: time),
                destination: box,
                filter: FilterEntry.entries(of: entry.filter, at: time),
                radius: entry.radius.sampled(at: time, as: LookStructureTable.length).number ?? 0,
                border: MediaBorder(
                    sampled: entry.border.sampled(at: time, as: LookStructureTable.border),
                    factor: factor
                ),
                shadow: DropShadow(
                    sampled: entry.shadow.sampled(at: time, as: LookStructureTable.shadow),
                    factor: factor,
                    carried: 1
                )
            ))
        } else if let solid = entry.solid {
            content = .path(PathItem(filling: box, color: solid))
        } else {
            return []
        }

        let item = DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            mask: entry.masks(at: time),
            trackMatte: trackMatte,
            content: content,
            origin: origin
        )
        return [item]
    }

    // A storyline clip with a corner pin drawn flat in its box B, `[0, 0, w, h]`, in a nested list of D, B and its
    // shadow, with B's top left at (-x, -y) for D at (x, y), its masks inside. The group's `rect` is B in the list, its
    // `dest` B and its corner pin Q(t); it carries the clip's track matte, and its opacity and blend are the outer
    // item's. Nil for a solid, which takes no corner pin, and where the corner pin draws nothing: B has no area or Q(t)
    // is not strictly convex. A storyline clip's corner pin is in output pixels and does not track.
    private func group(
        of entry: ResolvedStorylineClip,
        cornerPin: ResolvedCornerPin,
        trackMatte: ItemTrackMatte?,
        compositing: Compositing,
        at time: Double,
        seed: Int
    ) -> DisplayItem? {
        let quad = cornerPin.points.mapValues { $0.sampled(\.fixed) }.value(at: time)
        guard let media = entry.media, cornerPin.size.width > 0, cornerPin.size.height > 0, quad.isStrictlyConvex else {
            return nil
        }

        let box = Rectangle(x: 0, y: 0, width: cornerPin.size.width, height: cornerPin.size.height)
        let item = PictureItem(
            source: source(
                of: media,
                colorSpace: entry.colorSpace,
                isToneMapped: entry.isToneMapped,
                at: entry.mediaTime(at: time),
                seed: seed
            ),
            rectangle: entry.crop(at: time),
            destination: box,
            filter: FilterEntry.entries(of: entry.filter, at: time),
            radius: entry.radius.sampled(at: time, as: LookStructureTable.length).number ?? 0,
            border: MediaBorder(sampled: entry.border.sampled(at: time, as: LookStructureTable.border), factor: 1),
            shadow: DropShadow(sampled: entry.shadow.sampled(at: time, as: LookStructureTable.shadow), factor: 1, carried: 1)
        )
        let bounds = item.shadow.map { box.union($0.castBounds(of: box)) } ?? box
        let shift = AffineTransform(translation: Point(x: -bounds.x, y: -bounds.y))
        let mask = entry.masks(at: time).map { mask in
            ItemMask(
                geometry: mask.geometry,
                transform: mask.transform.concatenating(shift),
                feather: mask.feather,
                isInverted: mask.isInverted,
                mode: mask.mode
            )
        }
        let nested = DisplayItem(transform: shift, mask: mask, content: .picture(item), origin: ItemOrigin(entry: entry))

        return DisplayItem(
            trackMatte: trackMatte,
            content: .picture(PictureItem(
                source: .displayList(DisplayList(
                    size: Size(width: bounds.width, height: bounds.height),
                    background: .transparent,
                    compositing: compositing,
                    seed: seed,
                    items: [nested]
                )),
                rectangle: Rectangle(x: -bounds.x, y: -bounds.y, width: box.width, height: box.height),
                destination: box,
                cornerPin: quad
            )),
            origin: ItemOrigin(entry: entry)
        )
    }

    // A nested sequence's list carries no colour space, since its pictures carry what the decoder needs.
    private func source(
        of media: ResolvedMediaContent,
        colorSpace: ColorSpace?,
        isToneMapped: Bool?,
        at mediaTime: Double,
        seed: Int
    ) -> PictureItemSource {
        switch media {
        case let .pinned(media):
            .media(MediaFrame(
                media: media,
                mediaTime: mediaTime,
                reading: .working(colorSpace: colorSpace, targetPeak: isToneMapped == true ? targetPeak : nil)
            ))

        case let .nested(sequence):
            .displayList(displayList(of: sequence, at: mediaTime, seed: seed, colorSpace: nil))
        }
    }

    private func matte(
        of matte: ResolvedMatte,
        at progress: Double
    ) -> PictureMatte {
        PictureMatte(
            frame: MediaFrame(
                media: matte.media,
                progress: progress,
                reading: .analysis(colorSpace: matte.media.colorSpace)
            ),
            progress: transitionSampler.matteProgress(easedBy: matte.ease, at: progress),
            softness: matte.softness,
            isInverted: matte.isInverted
        )
    }

    private func coverItems(
        of transition: ActiveTransition?,
        in frame: Rectangle,
        at time: Double
    ) -> [DisplayItem] {
        guard let transition, let cover = transition.transition.cover else { return [] }

        let progress = transitionSampler.progress(through: transition.range, at: time)
        let opacity = transitionSampler.coverOpacity(of: cover.span, at: progress)
        switch cover.source {
        case let .color(color):
            return [DisplayItem(opacity: opacity, content: .path(PathItem(filling: frame, color: color)))]

        case let .media(media):
            let picture = PictureItem(
                source: .media(MediaFrame(
                    media: media,
                    progress: progress,
                    reading: .working(colorSpace: media.colorSpace, targetPeak: targetPeak)
                )),
                rectangle: nil,
                destination: frame
            )
            return [DisplayItem(opacity: opacity, content: .picture(picture))]
        }
    }
}
