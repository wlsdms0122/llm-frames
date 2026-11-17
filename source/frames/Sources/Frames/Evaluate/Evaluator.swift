//
//  Evaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Evaluates a resolved sequence into the display list of one output frame at a sequence time, every value sampled.
// Lists nested in it, for storyline units and compound clips, carry its seed.
package struct Evaluator: Sendable {
    // MARK: - Property
    // Behind a nested list, so what it leaves uncovered shows what lies below its picture.
    private static let transparent = Color(written: "#00000000")

    private let clipEvaluator = ClipEvaluator()
    private let seeder = GrainSeeder()
    private let transitionSampler = TransitionSampler()

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func displayList(
        of sequence: ResolvedSequence,
        at time: Double
    ) -> DisplayList {
        displayList(of: sequence, at: time, seed: seeder.seed(at: time, fps: sequence.format.fps))
    }

    // MARK: - Private
    // Bottom first: unparented clips on negative lanes, the storyline units, the transition cover, the background
    // outside the content rect, and unparented clips on positive lanes.
    private func displayList(
        of sequence: ResolvedSequence,
        at time: Double,
        seed: Int
    ) -> DisplayList {
        let format = sequence.format
        let transition = ActiveTransition(storyline: sequence.storyline, at: time)
        let items = clipItems(of: sequence, parent: nil, side: .below, at: time, seed: seed)
            + unitItems(of: sequence, transition: transition, at: time, seed: seed)
            + coverItems(of: transition, in: format.content, at: time)
            + [outsideItem(of: format)]
            + clipItems(of: sequence, parent: nil, side: .above, at: time, seed: seed)

        return DisplayList(size: format.size, background: format.background, seed: seed, items: items)
    }

    // The items of the connected and sequence clips composited at one level and visible at the time, bottom first by
    // lane and then in document order: the unparented clips of the sequence in output pixels when `parent` is nil, or
    // the clips parented to that storyline entry in its unit's coordinates, on the negative or positive lanes.
    private func clipItems(
        of sequence: ResolvedSequence,
        parent: Int?,
        side: LaneSide,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        let content = sequence.format.content
        let unit = Rectangle(x: 0, y: 0, width: content.width, height: content.height)
        let frame = Rectangle(x: 0, y: 0, width: sequence.format.size.width, height: sequence.format.size.height)
        let parentSpace = parent.map { ClipSpace(parent: sequence.storyline[$0], unit: unit, at: time) }

        return sequence.clips.enumerated()
            .filter { _, clip in
                // Every clip drawn has a lane.
                let lane = clip.lane ?? 1
                return (clip.isParented ? clip.storyline : nil) == parent
                    && (side == .below ? lane < 0 : lane > 0)
                    && TimeRange(start: clip.start, end: clip.end).contains(time)
            }
            .sorted { left, right in
                (left.element.lane ?? 1, left.offset) < (right.element.lane ?? 1, right.offset)
            }
            .flatMap { _, clip in
                let space = parentSpace ?? .output(room: clip.storyline == nil ? frame : content, frame: frame)
                let picture = picture(of: clip, at: time, seed: seed)
                let origin = ItemOrigin(clip: clip)
                return clipEvaluator.items(of: clip, in: space, picture: picture, at: time).map { $0.drawn(by: origin) }
            }
    }

    // A media clip's picture at the time: a still's one frame, or the frame or nested list at its media time.
    private func picture(
        of clip: ResolvedClip,
        at time: Double,
        seed: Int
    ) -> PictureItemSource? {
        guard case let .media(media) = clip.content else { return nil }

        return source(of: media.media, at: media.timing?.mediaTime(at: time) ?? 0, seed: seed)
    }

    // The units visible at the time, bottom first. During a transition the two it joins are visible, stacked as its
    // `over` says, and the incoming one takes its matte. Elsewhere the drawn ranges are the edit ranges, so the one
    // entry whose edit range holds the time is.
    private func unitItems(
        of sequence: ResolvedSequence,
        transition: ActiveTransition?,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        let content = sequence.format.content
        guard let transition else {
            let storyline = sequence.storyline
            return storyline.indices
                .filter { TimeRange(start: storyline[$0].start, end: storyline[$0].end).contains(time) }
                .map { index in
                    unitItem(
                        of: index,
                        in: sequence,
                        presentation: UnitPresentation(sample: .none, content: content),
                        matte: nil,
                        at: time,
                        seed: seed
                    )
                }
        }

        let progress = transitionSampler.progress(through: transition.range, at: time)
        let spans = transition.transition
        return spans.over.bottomFirst.map { order in
            switch order {
            case .incoming:
                unitItem(
                    of: transition.incoming,
                    in: sequence,
                    presentation: transitionSampler.unit(moving: spans.incoming, in: content, at: progress),
                    matte: spans.matte.map { matte(of: $0, at: progress) },
                    at: time,
                    seed: seed
                )

            case .outgoing:
                unitItem(
                    of: transition.outgoing,
                    in: sequence,
                    presentation: transitionSampler.unit(moving: spans.outgoing, in: content, at: progress),
                    matte: nil,
                    at: time,
                    seed: seed
                )
            }
        }
    }

    // A unit drawn as one picture of its nested list, the size of the content rect and in its coordinates, so the
    // transition's motion, reveal and matte act on it whole, and the content rect cuts it.
    private func unitItem(
        of index: Int,
        in sequence: ResolvedSequence,
        presentation: UnitPresentation,
        matte: PictureMatte?,
        at time: Double,
        seed: Int
    ) -> DisplayItem {
        let content = sequence.format.content
        let unit = Rectangle(x: 0, y: 0, width: content.width, height: content.height)
        let items = clipItems(of: sequence, parent: index, side: .below, at: time, seed: seed)
            + pictureItems(of: sequence.storyline[index], filling: unit, at: time, seed: seed)
            + clipItems(of: sequence, parent: index, side: .above, at: time, seed: seed)
        let list = DisplayList(
            size: Size(width: unit.width, height: unit.height),
            background: Self.transparent,
            seed: seed,
            items: items
        )

        let picture = PictureItem(source: .displayList(list), rectangle: unit, destination: content, matte: matte)

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            mask: content,
            reveal: presentation.reveal,
            content: .picture(picture),
            origin: ItemOrigin(entry: sequence.storyline[index])
        )
    }

    // A storyline entry's own picture over the whole unit: its media's conformed crop with its filter, or the fill of
    // a solid.
    private func pictureItems(
        of entry: ResolvedStorylineClip,
        filling unit: Rectangle,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        let origin = ItemOrigin(entry: entry)
        guard let media = entry.media else {
            return entry.solid.map { [DisplayItem(content: .fill(FillItem(rectangle: unit, color: $0)), origin: origin)] }
                ?? []
        }

        let picture = PictureItem(
            source: source(of: media, at: entry.mediaTime(at: time), seed: seed),
            rectangle: entry.crop(at: time),
            destination: unit,
            filter: entry.filter
        )
        return [DisplayItem(content: .picture(picture), origin: origin)]
    }

    private func source(
        of media: ResolvedMediaContent,
        at mediaTime: Double,
        seed: Int
    ) -> PictureItemSource {
        switch media {
        case let .pinned(media):
            .media(MediaFrame(media: media, mediaTime: mediaTime))

        case let .nested(sequence):
            .displayList(nestedDisplayList(of: sequence, at: mediaTime, seed: seed))
        }
    }

    // A nested sequence's list at a media time, held inside `[0, duration)`.
    private func nestedDisplayList(
        of sequence: ResolvedSequence,
        at time: Double,
        seed: Int
    ) -> DisplayList {
        displayList(of: sequence, at: min(max(time, 0), sequence.format.duration - .timeResolution), seed: seed)
    }

    // The matte's frame follows the transition's progress, and the luminance it shows below follows its own ease.
    private func matte(
        of matte: ResolvedMatte,
        at progress: Double
    ) -> PictureMatte {
        PictureMatte(
            frame: MediaFrame(media: matte.media, progress: progress),
            progress: transitionSampler.matteProgress(easedBy: matte.ease, at: progress),
            softness: matte.softness,
            isInverted: matte.isInverted
        )
    }

    // A transition's cover over both units: its colour or its media's frame stretched over the content rect, at the
    // opacity its keys give.
    private func coverItems(
        of transition: ActiveTransition?,
        in content: Rectangle,
        at time: Double
    ) -> [DisplayItem] {
        guard let transition, let cover = transition.transition.cover else { return [] }

        let progress = transitionSampler.progress(through: transition.range, at: time)
        let opacity = transitionSampler.coverOpacity(of: cover.span, at: progress)
        switch cover.source {
        case let .color(color):
            return [DisplayItem(opacity: opacity, content: .fill(FillItem(rectangle: content, color: color)))]

        case let .media(media):
            let picture = PictureItem(
                source: .media(MediaFrame(media: media, progress: progress)),
                rectangle: nil,
                destination: content
            )
            return [DisplayItem(opacity: opacity, content: .picture(picture))]
        }
    }

    // The background over the whole frame but the content rect, so nothing drawn in a unit shows outside it.
    private func outsideItem(of format: ResolvedFormat) -> DisplayItem {
        let frame = Rectangle(x: 0, y: 0, width: format.size.width, height: format.size.height)
        let fill = FillItem(
            rectangle: frame,
            color: format.background,
            hole: RoundedRectangle(rectangle: format.content, radius: 0)
        )

        return DisplayItem(content: .fill(fill))
    }
}
