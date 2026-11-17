//
//  Evaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Evaluates a resolved sequence into the display list of one output frame at a sequence time, every value sampled.
// Lists nested in it, for storyline pictures and compound clips, carry its seed.
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
    // Bottom first: clips on negative lanes, the storyline pictures, the transition cover, and clips on positive lanes.
    private func displayList(
        of sequence: ResolvedSequence,
        at time: Double,
        seed: Int
    ) -> DisplayList {
        let format = sequence.format
        let transition = ActiveTransition(storyline: sequence.storyline, at: time)
        let items = clipItems(of: sequence, side: .below, at: time, seed: seed)
            + storylineItems(of: sequence, transition: transition, at: time, seed: seed)
            + coverItems(of: transition, in: format.frame, at: time)
            + clipItems(of: sequence, side: .above, at: time, seed: seed)

        return DisplayList(size: format.size, background: format.background, seed: seed, items: items)
    }

    // The items of the connected and sequence clips on the negative or positive lanes and visible at the time, bottom
    // first by lane and then in document order, each in the space its parent gives it.
    private func clipItems(
        of sequence: ResolvedSequence,
        side: LaneSide,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        let parents = ParentEvaluator(sequence: sequence)

        return sequence.clips.enumerated()
            .filter { _, clip in
                // Every clip drawn has a lane.
                let lane = clip.lane ?? 1
                return (side == .below ? lane < 0 : lane > 0) && TimeRange(start: clip.start, end: clip.end).contains(time)
            }
            .sorted { left, right in
                (left.element.lane ?? 1, left.offset) < (right.element.lane ?? 1, right.offset)
            }
            .flatMap { _, clip in
                let space = parents.space(of: clip, at: time)
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

    // The storyline pictures visible at the time, bottom first. During a transition the two it joins are visible,
    // stacked as its `over` says, and the incoming one takes its matte. Elsewhere the drawn ranges are the edit ranges,
    // so the one entry whose edit range holds the time is.
    private func storylineItems(
        of sequence: ResolvedSequence,
        transition: ActiveTransition?,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        guard let transition else {
            let storyline = sequence.storyline
            return storyline.indices
                .filter { TimeRange(start: storyline[$0].start, end: storyline[$0].end).contains(time) }
                .map { index in storylineItem(of: index, in: sequence, matte: nil, at: time, seed: seed) }
        }

        let progress = transitionSampler.progress(through: transition.range, at: time)
        let spans = transition.transition
        return spans.over.bottomFirst.map { order in
            switch order {
            case .incoming:
                storylineItem(
                    of: transition.incoming,
                    in: sequence,
                    matte: spans.matte.map { matte(of: $0, at: progress) },
                    at: time,
                    seed: seed
                )

            case .outgoing:
                storylineItem(of: transition.outgoing, in: sequence, matte: nil, at: time, seed: seed)
            }
        }
    }

    // A storyline picture is two items: the outer one a picture of a nested list the size of the frame, carrying the
    // clip's transition motion about the centre of the frame, its opacity and reveal, and the matte; the inner one,
    // the one item of that list, its media or its fill.
    private func storylineItem(
        of index: Int,
        in sequence: ResolvedSequence,
        matte: PictureMatte?,
        at time: Double,
        seed: Int
    ) -> DisplayItem {
        let frame = sequence.format.frame
        let entry = sequence.storyline[index]
        let items = innerItems(of: entry, filling: frame, at: time, seed: seed)
        let list = DisplayList(size: sequence.format.size, background: Self.transparent, seed: seed, items: items)
        let picture = PictureItem(source: .displayList(list), rectangle: frame, destination: frame, matte: matte)
        let sample = transitionSampler.motion(of: index, in: sequence.storyline, at: time)
        let presentation = ItemPresentation(area: frame, opacity: 1, motion: sample.motion)

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            reveal: sample.reveal.rectangle(wiping: frame, from: sample.revealFrom),
            content: .picture(picture),
            origin: ItemOrigin(entry: entry)
        )
    }

    // A storyline entry's own picture over the whole frame: its media's conformed crop with its filter, or the fill of
    // a solid.
    private func innerItems(
        of entry: ResolvedStorylineClip,
        filling frame: Rectangle,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        let origin = ItemOrigin(entry: entry)
        guard let media = entry.media else {
            return entry.solid.map { [DisplayItem(content: .fill(FillItem(rectangle: frame, color: $0)), origin: origin)] }
                ?? []
        }

        let picture = PictureItem(
            source: source(of: media, at: entry.mediaTime(at: time), seed: seed),
            rectangle: entry.crop(at: time),
            destination: frame,
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

    // A transition's cover over both storyline pictures: its colour or its media's frame stretched over the frame, at the opacity its
    // keys give.
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
            return [DisplayItem(opacity: opacity, content: .fill(FillItem(rectangle: frame, color: color)))]

        case let .media(media):
            let picture = PictureItem(
                source: .media(MediaFrame(media: media, progress: progress)),
                rectangle: nil,
                destination: frame
            )
            return [DisplayItem(opacity: opacity, content: .picture(picture))]
        }
    }
}
