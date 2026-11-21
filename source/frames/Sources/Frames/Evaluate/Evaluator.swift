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
//
// A frame where a clip with `motionBlur` owns a value it reads is N samples, each the whole list of the frame at one
// instant of its exposure (FRAMES-29). Membership and content are those of T in every sample: which clips draw, the
// active transition, media frames and the seed. Each owner's values are read at the time `SampleInstant` gives it by
// its switch, and a compound clip's clock carries the instant into its nested sequence whatever its switch.
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
    // The frame at `time`: its samples where a clip with `motionBlur` owns a value it reads, and otherwise the list
    // the frame has without motion blur.
    package func displayList(
        of sequence: ResolvedSequence,
        at time: Double
    ) -> DisplayList {
        let list = displayListWithoutMotionBlur(of: sequence, at: time)
        guard sequence.hasMotionBlur else { return list }

        let format = sequence.format
        let evaluator = Evaluator(targetPeak: format.peakLuminance)
        let reads = MotionBlurReads()
        let instants = format.shutter.instants(at: time, fps: format.fps)
        let sample = { (instant: Double) in
            evaluator.items(of: sequence, at: SampleInstant(instant: instant, frameTime: time, reads: reads), seed: list.seed)
        }

        // The first sample tells whether the frame reads a value a clip with `motionBlur` owns.
        let first = sample(instants[0])
        guard reads.readsMotionBlur else { return list }

        return DisplayList(
            size: list.size,
            background: list.background,
            colorSpace: list.colorSpace,
            peak: list.peak,
            compositing: list.compositing,
            seed: list.seed,
            samples: [first] + instants.dropFirst().map(sample)
        )
    }

    // The list the frame at `time` has without motion blur, every value at `time`, which `evaluate` and `locate`
    // report (FRAMES-23).
    package func displayListWithoutMotionBlur(
        of sequence: ResolvedSequence,
        at time: Double
    ) -> DisplayList {
        let format = sequence.format

        return Evaluator(targetPeak: format.peakLuminance).displayList(
            of: sequence,
            at: SampleInstant(frameTime: time),
            seed: seeder.seed(at: time, fps: format.fps),
            colorSpace: format.colorSpace,
            peak: format.peak
        )
    }

    // MARK: - Private
    // The sample's `frameTime` is the frame's instant on the sequence's clock, at which its membership and content are
    // taken.
    private func displayList(
        of sequence: ResolvedSequence,
        at sample: SampleInstant,
        seed: Int,
        colorSpace: ColorSpace?,
        peak: Double? = nil
    ) -> DisplayList {
        let format = sequence.format

        return DisplayList(
            size: format.size,
            background: format.background,
            colorSpace: colorSpace,
            peak: peak,
            compositing: format.compositing,
            seed: seed,
            items: items(of: sequence, at: sample, seed: seed)
        )
    }

    private func items(
        of sequence: ResolvedSequence,
        at sample: SampleInstant,
        seed: Int
    ) -> [DisplayItem] {
        let transition = ActiveTransition(storyline: sequence.storyline, at: sample.frameTime)
        let parents = ParentEvaluator(sequence: sequence)

        return clipItems(of: sequence, parents: parents, side: .below, at: sample, seed: seed)
            + storylineItems(of: sequence, parents: parents, transition: transition, at: sample, seed: seed)
            + coverItems(of: transition, in: sequence.storyline, frame: sequence.format.frame, at: sample)
            + clipItems(of: sequence, parents: parents, side: .above, at: sample, seed: seed)
    }

    private func clipItems(
        of sequence: ResolvedSequence,
        parents: ParentEvaluator,
        side: LaneSide,
        at sample: SampleInstant,
        seed: Int
    ) -> [DisplayItem] {
        sequence.clips.enumerated()
            .filter { _, clip in
                // Resolution sets every clip's lane.
                let lane = clip.lane ?? 1
                return (side == .below ? lane < 0 : lane > 0)
                    && TimeRange(start: clip.start, end: clip.end).contains(sample.frameTime)
                    && !sequence.isMatte(clip)
            }
            .sorted { left, right in
                (left.element.lane ?? 1, left.offset) < (right.element.lane ?? 1, right.offset)
            }
            .flatMap { _, clip in
                let trackMatte = trackMatte(clip.trackMatte, in: sequence, parents: parents, at: sample, seed: seed)
                return items(
                    of: clip,
                    parents: parents,
                    trackMatte: trackMatte,
                    compositing: sequence.format.compositing,
                    at: sample,
                    seed: seed
                )
            }
    }

    private func items(
        of clip: ResolvedClip,
        parents: ParentEvaluator,
        trackMatte: ItemTrackMatte?,
        compositing: Compositing,
        at sample: SampleInstant,
        seed: Int
    ) -> [DisplayItem] {
        let picture = picture(of: clip, at: sample, seed: seed)
        let origin = ItemOrigin(clip: clip)
        let time = clip.valueTime(in: sample)

        return clipEvaluator.items(
            of: clip,
            in: parents.space(of: clip, at: time),
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
        at sample: SampleInstant,
        seed: Int
    ) -> ItemTrackMatte? {
        sequence.matteChain(from: trackMatte).reversed().reduce(ItemTrackMatte?.none) { inner, link in
            let items = TimeRange(start: link.clip.start, end: link.clip.end).contains(sample.frameTime)
                ? self.items(
                    of: link.clip,
                    parents: parents,
                    trackMatte: inner,
                    compositing: sequence.format.compositing,
                    at: sample,
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
        at sample: SampleInstant,
        seed: Int
    ) -> PictureItemSource? {
        guard case let .media(media) = clip.content else { return nil }

        return source(
            of: media.media,
            colorSpace: media.colorSpace,
            isToneMapped: media.isToneMapped,
            clock: media.clock,
            in: TimeRange(start: clip.start, end: clip.end),
            at: sample,
            seed: seed
        )
    }

    // Out of a transition the entries' ranges are their edit ranges, so at most one holds the time.
    private func storylineItems(
        of sequence: ResolvedSequence,
        parents: ParentEvaluator,
        transition: ActiveTransition?,
        at sample: SampleInstant,
        seed: Int
    ) -> [DisplayItem] {
        guard let transition else {
            let storyline = sequence.storyline
            return storyline.indices
                .filter { TimeRange(start: storyline[$0].start, end: storyline[$0].end).contains(sample.frameTime) }
                .map { index in
                    storylineItem(of: index, in: sequence, parents: parents, matte: nil, at: sample, seed: seed)
                }
        }

        let spans = transition.transition
        let progress = transitionSampler.progress(
            of: transition.transition,
            broughtBy: transition.incoming,
            in: sequence.storyline,
            at: sample
        )
        return spans.over.bottomFirst.map { order in
            switch order {
            case .incoming:
                storylineItem(
                    of: transition.incoming,
                    in: sequence,
                    parents: parents,
                    matte: spans.matte.map { matte(of: $0, at: progress) },
                    at: sample,
                    seed: seed
                )

            case .outgoing:
                storylineItem(
                    of: transition.outgoing,
                    in: sequence,
                    parents: parents,
                    matte: nil,
                    at: sample,
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
        at sample: SampleInstant,
        seed: Int
    ) -> DisplayItem {
        let frame = sequence.format.frame
        let entry = sequence.storyline[index]
        let trackMatte = trackMatte(entry.trackMatte, in: sequence, parents: parents, at: sample, seed: seed)
        let items = innerItems(
            of: entry,
            in: sequence.storyline.drawnRange(ofEntry: index),
            trackMatte: trackMatte,
            at: sequence.storyline.valueTime(ofEntry: index, in: sample),
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
        let motion = transitionSampler.motion(of: index, in: sequence.storyline, at: sample)
        let presentation = ItemPresentation(area: frame, opacity: 1, motion: motion.motion)

        return DisplayItem(
            transform: presentation.transform,
            opacity: presentation.opacity,
            blend: entry.blend,
            reveal: motion.reveal.rectangle(wiping: frame, from: motion.revealFrom),
            content: .picture(picture),
            origin: ItemOrigin(entry: entry)
        )
    }

    // `time` is the entry's value time, and its sample's T is the time its media is shown at.
    private func innerItems(
        of entry: ResolvedStorylineClip,
        in window: TimeRange,
        trackMatte: ItemTrackMatte?,
        at time: SampleTime,
        seed: Int
    ) -> [DisplayItem] {
        let origin = ItemOrigin(entry: entry)
        let box = Rectangle(x: 0, y: 0, width: entry.box.size.width, height: entry.box.size.height)
        let presentation = entry.presentation(at: time)
        // A box's own pixels are carried at the entry's scale, so a carried length is written as it is.
        let factor = entry.scale.value(at: time).factor
        let content: DisplayContent
        if let media = entry.media {
            content = .picture(PictureItem(
                source: source(
                    of: media,
                    colorSpace: entry.colorSpace,
                    isToneMapped: entry.isToneMapped,
                    clock: entry.clock,
                    in: window,
                    at: time.sample,
                    seed: seed
                ),
                rectangle: entry.crop(at: time),
                destination: box,
                filter: FilterEntry.entries(of: entry.filter, at: time),
                radius: entry.radius.sampled(at: time, as: LookStructureTable.length).number ?? 0,
                border: MediaBorder(
                    sampled: entry.border.sampled(at: time, as: LookStructureTable.border),
                    factor: factor,
                    isSample: time.sample.isSample
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

    // A nested sequence's list carries no colour space, since its pictures carry what the decoder needs. The media time
    // at the sample's T picks the media frame and a nested sequence's membership and content. A clip without a clock
    // shows media time 0.
    private func source(
        of media: ResolvedMediaContent,
        colorSpace: ColorSpace?,
        isToneMapped: Bool?,
        clock: MediaClock?,
        in window: TimeRange,
        at sample: SampleInstant,
        seed: Int
    ) -> PictureItemSource {
        let mediaTime = clock?.mediaTime(atSequenceTime: sample.frameTime) ?? 0
        switch media {
        case let .pinned(media):
            return .media(MediaFrame(
                media: media,
                mediaTime: mediaTime,
                reading: .working(colorSpace: colorSpace, targetPeak: isToneMapped == true ? targetPeak : nil)
            ))

        case let .nested(sequence):
            guard let reads = sample.reads else {
                return .displayList(displayList(
                    of: sequence,
                    at: SampleInstant(frameTime: mediaTime),
                    seed: seed,
                    colorSpace: nil
                ))
            }

            // The clock carries the instant whatever the switch, its input clamped to T's side of its jumps: the
            // window's ends and those of its `timeRemap` (FRAMES-29).
            let instant = clock?.mediaTime(atSequenceTime: window.held(sample.instant), onSideOf: sample.frameTime)
                ?? mediaTime
            let nested = SampleInstant(instant: instant, frameTime: mediaTime, reads: reads)
            return .displayList(displayList(of: sequence, at: nested, seed: seed, colorSpace: nil))
        }
    }

    // The matte's media frame is picked at the progress at T.
    private func matte(
        of matte: ResolvedMatte,
        at progress: SampleProgress
    ) -> PictureMatte {
        PictureMatte(
            frame: MediaFrame(
                media: matte.media,
                progress: progress.frameProgress,
                reading: .analysis(colorSpace: matte.media.colorSpace)
            ),
            progress: transitionSampler.matteProgress(easedBy: matte.ease, at: progress),
            softness: matte.softness,
            isInverted: matte.isInverted
        )
    }

    // The cover's media frame is picked at the progress at T, and its opacity follows the incoming clip's progress.
    private func coverItems(
        of transition: ActiveTransition?,
        in storyline: [ResolvedStorylineClip],
        frame: Rectangle,
        at sample: SampleInstant
    ) -> [DisplayItem] {
        guard let transition, let cover = transition.transition.cover else { return [] }

        let progress = transitionSampler.progress(
            of: transition.transition,
            broughtBy: transition.incoming,
            in: storyline,
            at: sample
        )
        let opacity = transitionSampler.coverOpacity(of: cover.span, at: progress)
        switch cover.source {
        case let .color(color):
            return [DisplayItem(opacity: opacity, content: .path(PathItem(filling: frame, color: color)))]

        case let .media(media):
            let picture = PictureItem(
                source: .media(MediaFrame(
                    media: media,
                    progress: progress.frameProgress,
                    reading: .working(colorSpace: media.colorSpace, targetPeak: targetPeak)
                )),
                rectangle: nil,
                destination: frame
            )
            return [DisplayItem(opacity: opacity, content: .picture(picture))]
        }
    }
}
