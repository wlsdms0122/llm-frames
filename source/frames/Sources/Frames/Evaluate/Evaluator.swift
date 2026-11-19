//
//  Evaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Lists nested in a display list, for storyline pictures, compound clips and track mattes, carry its seed. A clip used
// as a track matte draws no item of its own, and its children are drawn as usual.
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
    private func displayList(
        of sequence: ResolvedSequence,
        at time: Double,
        seed: Int
    ) -> DisplayList {
        let format = sequence.format
        let transition = ActiveTransition(storyline: sequence.storyline, at: time)
        let parents = ParentEvaluator(sequence: sequence)
        let items = clipItems(of: sequence, parents: parents, side: .below, at: time, seed: seed)
            + storylineItems(of: sequence, parents: parents, transition: transition, at: time, seed: seed)
            + coverItems(of: transition, in: format.frame, at: time)
            + clipItems(of: sequence, parents: parents, side: .above, at: time, seed: seed)

        return DisplayList(size: format.size, background: format.background, seed: seed, items: items)
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
                return items(of: clip, parents: parents, trackMatte: trackMatte, at: time, seed: seed)
            }
    }

    private func items(
        of clip: ResolvedClip,
        parents: ParentEvaluator,
        trackMatte: ItemTrackMatte?,
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        let space = parents.space(of: clip, at: time)
        let picture = picture(of: clip, at: time, seed: seed)
        let origin = ItemOrigin(clip: clip)

        return clipEvaluator.items(of: clip, in: space, picture: picture, trackMatte: trackMatte, at: time)
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
                ? self.items(of: link.clip, parents: parents, trackMatte: inner, at: time, seed: seed)
                : []
            let source = DisplayList(
                size: sequence.format.size,
                background: Self.transparent,
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

        return source(of: media.media, at: media.clock?.mediaTime(atSequenceTime: time) ?? 0, seed: seed)
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
    // motion and the matte, so the transition motion acts on everything inside it.
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
        let items = innerItems(of: entry, trackMatte: trackMatte, at: time, seed: seed)
        let list = DisplayList(size: sequence.format.size, background: Self.transparent, seed: seed, items: items)
        let picture = PictureItem(source: .displayList(list), rectangle: frame, destination: frame, matte: matte)
        let sample = transitionSampler.motion(of: index, in: sequence.storyline, at: time)
        let presentation = ItemPresentation(area: frame, opacity: 1, motion: sample.motion)

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
        at time: Double,
        seed: Int
    ) -> [DisplayItem] {
        let origin = ItemOrigin(entry: entry)
        let box = Rectangle(x: 0, y: 0, width: entry.box.size.width, height: entry.box.size.height)
        let presentation = entry.presentation(at: time)
        let content: DisplayContent
        if let media = entry.media {
            content = .picture(PictureItem(
                source: source(of: media, at: entry.mediaTime(at: time), seed: seed),
                rectangle: entry.crop(at: time),
                destination: box,
                filter: entry.filter,
                radius: entry.radius,
                border: entry.border,
                shadow: entry.shadow
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

    private func source(
        of media: ResolvedMediaContent,
        at mediaTime: Double,
        seed: Int
    ) -> PictureItemSource {
        switch media {
        case let .pinned(media):
            .media(MediaFrame(media: media, mediaTime: mediaTime))

        case let .nested(sequence):
            .displayList(displayList(of: sequence, at: mediaTime, seed: seed))
        }
    }

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
                source: .media(MediaFrame(media: media, progress: progress)),
                rectangle: nil,
                destination: frame
            )
            return [DisplayItem(opacity: opacity, content: .picture(picture))]
        }
    }
}
