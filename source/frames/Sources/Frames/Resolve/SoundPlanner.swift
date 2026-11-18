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
    // MARK: - Initializer
    // MARK: - Public
    // `time` is the plan whose windows tracking narrowed, `written` its clips as `time.clips` lists them, and the nested
    // plans those of its storyline clips and its other clips.
    func sound(
        of time: TimePlan,
        written: [Clip],
        storylineNested: [SequencePlan?],
        clipNested: [SequencePlan?]
    ) -> [SoundPlan] {
        let clipSound = { (index: Int) in
            self.sound(of: time.clips[index], written: written[index], nested: clipNested[index])
        }
        let storyline = time.storyline.indices.flatMap { index in
            let connected = time.clips.indices.filter { clip in
                written[clip].clipPlace == .connected && time.clips[clip].storyline == index
            }

            return [sound(of: time, index: index, nested: storylineNested[index])] + connected.map(clipSound)
        }
        let sequence = time.clips.indices.filter { written[$0].clipPlace == .sequence }.map(clipSound)

        return (storyline + sequence).compactMap { $0 }
    }

    // MARK: - Private
    // A storyline clip plays over its drawn range, its handles included, and its media exists from media time 0 to the
    // end of the media. A remapped clip plays no sound.
    private func sound(
        of time: TimePlan,
        index: Int,
        nested: SequencePlan?
    ) -> SoundPlan? {
        let plan = time.storyline[index]
        guard let media = plan.source.media, media.hasSound, plan.timeRemap == nil else { return nil }

        let written = time.sequence.storyline[index].media
        let map = plan.map
        let exists = TimeRange(start: map.sequenceTime(ofClipTime: 0), end: map.sequenceTime(ofClipTime: media.duration))
        guard let audible = plan.drawn.intersection(exists) else { return nil }

        let outgoing = time.storyline.indices.contains(index + 1) ? time.storyline[index + 1].transition : nil
        return SoundPlan(
            place: plan.place,
            media: media,
            played: PlayedRange(map: map, out: plan.source.clipRange.end, loop: false),
            range: plan.drawn,
            audible: audible,
            volume: sequenceTime(written?.volume, clock: map, default: 1),
            pan: sequenceTime(written?.pan, clock: map, default: 0),
            fadeIn: fadeIn(written?.fadeIn, over: plan.drawn),
            fadeOut: fadeOut(written?.fadeOut, over: plan.drawn),
            incoming: plan.transition.map(Crossfade.init(plan:)),
            outgoing: outgoing.map(Crossfade.init(plan:)),
            nested: nested?.sound ?? []
        )
    }

    // A media clip plays its visible window, from `in` at the start of its window. Past `out` it repeats when it loops
    // and is silent when it does not. A remapped clip plays no sound.
    private func sound(
        of plan: ClipPlan,
        written: Clip,
        nested: SequencePlan?
    ) -> SoundPlan? {
        guard
            case let .media(clipMedia) = written.content,
            let media = plan.media,
            let played = plan.timing?.played,
            media.hasSound
        else {
            return nil
        }

        let exists = TimeRange(
            start: played.origin,
            end: played.loop ? plan.visible.end : played.map.sequenceTime(ofClipTime: played.out)
        )
        guard let audible = plan.visible.intersection(exists) else { return nil }

        return SoundPlan(
            place: plan.place,
            media: media,
            played: played,
            range: plan.visible,
            audible: audible,
            volume: sequenceTime(clipMedia.volume, clock: plan.clock, default: 1),
            pan: sequenceTime(clipMedia.pan, clock: plan.clock, default: 0),
            fadeIn: fadeIn(clipMedia.fadeIn, over: plan.visible),
            fadeOut: fadeOut(clipMedia.fadeOut, over: plan.visible),
            incoming: nil,
            outgoing: nil,
            nested: nested?.sound ?? []
        )
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
