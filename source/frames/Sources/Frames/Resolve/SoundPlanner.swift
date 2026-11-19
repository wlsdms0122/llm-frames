//
//  SoundPlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans every source of sound in a sequence, in document order: each storyline clip with sound, then its connected
// clips with sound, then the sequence clips with sound. Gains are multiplied when the mix is evaluated, not here.
struct SoundPlanner: Sendable {
    // MARK: - Property
    private let audioFilters: AudioFilterResolver

    // MARK: - Initializer
    init(presets: any PresetProvider) {
        self.audioFilters = AudioFilterResolver(presets: presets)
    }

    // MARK: - Public
    // `time` is the plan whose windows tracking narrowed, `written` its clips as `time.clips` lists them, and the nested
    // plans those of its storyline clips and its other clips.
    func sound(
        of time: TimePlan,
        written: [Clip],
        storylineNested: [SequencePlan?],
        clipNested: [SequencePlan?]
    ) throws -> [SoundPlan] {
        let clipSound = { (index: Int) in
            try self.sound(of: time.clips[index], written: written[index], nested: clipNested[index], time: time)
        }
        let storyline = try time.storyline.indices.flatMap { index in
            let connected = time.clips.indices.filter { clip in
                written[clip].clipPlace == .connected && time.clips[clip].storyline == index
            }

            return try [sound(of: time, index: index, nested: storylineNested[index])] + connected.map(clipSound)
        }
        let sequence = try time.clips.indices.filter { written[$0].clipPlace == .sequence }.map(clipSound)

        return (storyline + sequence).compactMap { $0 }
    }

    // MARK: - Private
    // A storyline clip plays over its drawn range, its handles included, moved out by its split, and its media exists
    // from media time 0 to the end of the media. Its own side of each crossfade moves with the edge it is at. A
    // remapped clip plays no sound.
    private func sound(
        of time: TimePlan,
        index: Int,
        nested: SequencePlan?
    ) throws -> SoundPlan? {
        let plan = time.storyline[index]
        let written = time.sequence.storyline[index].media
        guard let media = plan.source.media, media.hasSound, plan.timeRemap == nil else {
            try checkSilent(written, place: plan.place, kind: plan.source.kind)
            return nil
        }

        let map = plan.map
        let split = written?.split ?? SplitEdit()
        let range = split.moved(plan.drawn)
        let exists = TimeRange(start: map.sequenceTime(ofClipTime: 0), end: map.sequenceTime(ofClipTime: media.duration))
        let kind = PlaceKind.clip(plan.source.kind)
        let place = plan.place.appending(key: "split")
        try checkSequence(of: split, range: range, duration: time.duration, place: place, kind: kind)
        try checkMedia(of: split, range: range, exists: exists, place: place, kind: kind)
        guard let audible = range.intersection(exists) else { return nil }

        let outgoing = time.storyline.indices.contains(index + 1) ? time.storyline[index + 1].transition : nil
        return SoundPlan(
            place: plan.place,
            media: media,
            played: PlayedRange(map: map, out: plan.source.clipRange.end, loop: false),
            range: range,
            audible: audible,
            volume: sequenceTime(written?.volume, clock: map, default: 1),
            pan: sequenceTime(written?.pan, clock: map, default: 0),
            fadeIn: fadeIn(written?.fadeIn, over: range),
            fadeOut: fadeOut(written?.fadeOut, over: range),
            incoming: plan.transition.map { Crossfade(plan: $0, movedBy: -split.before) },
            outgoing: outgoing.map { Crossfade(plan: $0, movedBy: split.after) },
            nested: nested?.sound ?? [],
            audioFilter: try audioFilters.timed(
                written?.audioFilter,
                looks: looks(of: plan.place, kind: plan.source.kind, clock: map, instant: plan.instant, theme: time.theme)
            )
        )
    }

    // A media clip plays its visible window, from `in` at the start of its window. Past `out` it repeats when it loops
    // and is silent when it does not. A split moves the window's edges out on its time map: the media before `in`
    // plays before them, and the media after `out` or a loop continuing after them. A remapped clip plays no sound.
    private func sound(
        of plan: ClipPlan,
        written: Clip,
        nested: SequencePlan?,
        time: TimePlan
    ) throws -> SoundPlan? {
        guard case let .media(clipMedia) = written.content else { return nil }
        guard let media = plan.media, let played = plan.timing?.played, media.hasSound else {
            try checkSilent(clipMedia, place: plan.place, kind: plan.kind)
            return nil
        }

        let split = clipMedia.split ?? SplitEdit()
        let range = split.moved(plan.visible)
        let exists = TimeRange(
            start: split.before > 0 ? played.map.sequenceTime(ofClipTime: 0) : played.origin,
            end: played.loop
                ? range.end
                : played.map.sequenceTime(ofClipTime: split.after > 0 ? media.duration : played.out)
        )
        let kind = PlaceKind.clip(plan.kind)
        let place = plan.place.appending(key: "split")
        try checkSequence(of: split, range: range, duration: time.duration, place: place, kind: kind)
        try checkMedia(of: split, range: range, exists: exists, place: place, kind: kind)
        guard let audible = range.intersection(exists) else { return nil }

        return SoundPlan(
            place: plan.place,
            media: media,
            played: played,
            range: range,
            audible: audible,
            volume: sequenceTime(clipMedia.volume, clock: plan.clock, default: 1),
            pan: sequenceTime(clipMedia.pan, clock: plan.clock, default: 0),
            fadeIn: fadeIn(clipMedia.fadeIn, over: range),
            fadeOut: fadeOut(clipMedia.fadeOut, over: range),
            incoming: nil,
            outgoing: nil,
            nested: nested?.sound ?? [],
            audioFilter: try audioFilters.timed(
                clipMedia.audioFilter,
                looks: looks(of: plan.place, kind: plan.kind, clock: plan.clock, instant: plan.instant, theme: time.theme)
            )
        )
    }

    // A clip that plays no sound takes no audio filter and no split. A remapped clip's stop earlier, where its time is
    // planned.
    private func checkSilent(
        _ media: ClipMedia?,
        place: Place,
        kind: ClipKind
    ) throws {
        if media?.audioFilter != nil {
            throw ResolveError.audioFilterWithoutSound(place: place.appending(key: AudioFilterResolver.key), kind: .clip(kind))
        }
        if media?.split != nil {
            throw ResolveError.splitWithoutSound(place: place.appending(key: "split"), kind: .clip(kind))
        }
    }

    // A moved edge lies inside the sequence.
    private func checkSequence(
        of split: SplitEdit,
        range: TimeRange,
        duration: Double,
        place: Place,
        kind: PlaceKind
    ) throws {
        if split.before > 0, range.start.timeTicks < 0 {
            throw ResolveError.splitOutsideSequence(place: place.appending(key: "before"), kind: kind)
        }
        if split.after > 0, range.end.timeTicks > duration.timeTicks {
            throw ResolveError.splitOutsideSequence(place: place.appending(key: "after"), kind: kind)
        }
    }

    // A moved edge lies where the media holds sound.
    private func checkMedia(
        of split: SplitEdit,
        range: TimeRange,
        exists: TimeRange,
        place: Place,
        kind: PlaceKind
    ) throws {
        if split.before > 0, range.start.timeTicks < exists.start.timeTicks {
            throw ResolveError.splitPastMedia(place: place.appending(key: "before"), kind: kind)
        }
        if split.after > 0, range.end.timeTicks > exists.end.timeTicks {
            throw ResolveError.splitPastMedia(place: place.appending(key: "after"), kind: kind)
        }
    }

    // An audio filter has no theme layer and no lengths.
    private func looks(
        of place: Place,
        kind: ClipKind,
        clock: TimeMap,
        instant: Double,
        theme: MergedTheme
    ) -> ClipLookPlanner {
        ClipLookPlanner(place: place, kind: .clip(kind), clock: clock, instant: instant, scale: 1, theme: theme)
    }

    // Volume and pan keyframes are on the clip's clock, so they move into sequence time. A property left unwritten is its
    // default.
    private func sequenceTime(
        _ property: PropertyValue<Double>?,
        clock: TimeMap,
        default defaultValue: Double
    ) -> PropertyValue<Double> {
        property?.inSequenceTime(on: clock) ?? .value(defaultValue)
    }

    private func fadeIn(
        _ seconds: Double?,
        over range: TimeRange
    ) -> TimeRange? {
        guard let seconds, seconds > 0 else { return nil }

        return TimeRange(start: range.start, end: range.start + seconds)
    }

    private func fadeOut(
        _ seconds: Double?,
        over range: TimeRange
    ) -> TimeRange? {
        guard let seconds, seconds > 0 else { return nil }

        return TimeRange(start: range.end - seconds, end: range.end)
    }
}
