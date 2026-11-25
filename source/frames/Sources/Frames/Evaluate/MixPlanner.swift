//
//  MixPlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans the sound of a sequence without opening a file. Every compound clip and template instance is a bus, one for
// each repeat of a loop: its sounds' times mapped through its clock and cut to where it is heard, their pans added to
// its own, and its level on the bus, applied to their sum. A bus that holds no segment and no bus is silence and is
// left out.
package struct MixPlanner: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func mix(of sequence: ResolvedSequence) -> MixPlan {
        let fps = sequence.format.fps
        let length = sequence.format.mixLength
        let output = MixPath(
            layers: [],
            heard: TimeRange(start: 0, end: sequence.format.duration),
            clock: .sequence
        )
        let whole = TimeRange(start: 0, end: Double(length) / Double(MixPlan.sampleRate))
        let parts = sequence.audio.map { sound in self.parts(of: sound, through: output, fps: fps) }

        return MixPlan(
            length: length,
            segments: parts.flatMap(\.segments),
            buses: parts.flatMap(\.buses),
            filter: MixFilterEntry.entries(
                of: sequence.audioFilter,
                sampler: MixValueSampler(clock: .sequence, heard: whole, fps: fps)
            )
        )
    }

    // The plan of the sequence that plays one clip of the medium at `path` from media time 0 at volume 1, centred and
    // at speed 1 with no audio filter, as long as its sound, `duration` seconds. The file is not pinned.
    package func mix(
        ofMedium path: String,
        duration: Double
    ) -> MixPlan {
        let segment = MixSegment(
            media: .unpinned(path: path),
            mediaStart: 0,
            speed: 1,
            start: 0,
            end: duration,
            envelope: [EnvelopePoint(time: 0, value: 1), EnvelopePoint(time: duration, value: 1)],
            pan: [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: duration, value: 0)]
        )

        return MixPlan(length: Int((duration * Double(MixPlan.sampleRate)).rounded()), segments: [segment])
    }

    // MARK: - Private
    // A sound's segments, or its buses for a nested sequence, each in time order.
    private func parts(
        of sound: ResolvedSound,
        through path: MixPath,
        fps: Double
    ) -> (segments: [MixSegment], buses: [MixBus]) {
        let own = paths(of: sound, through: path)
        switch sound.source {
        case let .pinned(media):
            return (own.map { path in MixSegment(media: media, path: path, fps: fps) }, [])

        case let .nested(nested, audioFilter):
            return ([], own.compactMap { path in bus(of: nested, audioFilter: audioFilter, through: path, fps: fps) })
        }
    }

    // `audioFilter` is the nested sequence's own, its bus's chain.
    private func bus(
        of nested: [ResolvedSound],
        audioFilter: TimedValue,
        through path: MixPath,
        fps: Double
    ) -> MixBus? {
        let parts = nested.map { nested in self.parts(of: nested, through: path, fps: fps) }
        let segments = parts.flatMap(\.segments)
        let buses = parts.flatMap(\.buses)
        guard !segments.isEmpty || !buses.isEmpty else { return nil }

        return MixBus(path: path, segments: segments, buses: buses, nestedAudioFilter: audioFilter, fps: fps)
    }

    private func paths(
        of sound: ResolvedSound,
        through path: MixPath
    ) -> [MixPath] {
        let layers = path.layers + [MixLayer(sound: sound, clock: path.clock)]
        let played = sound.played.map
        guard let heard = path.heard.intersection(outermost(sound.audible, through: path.clock)) else { return [] }
        guard sound.played.loop else {
            return [MixPath(layers: layers, heard: heard, clock: composed(path.clock, played))]
        }

        // Every repeat starts at a boundary worked out the same way, so each starts exactly where the last ends. A
        // sound a split starts early plays the media before `in` and on into the first repeat, where the media does
        // not jump, so the first repeat starts where the sound does and its filters run on across both.
        let period = sound.played.naturalLength
        let boundary = { (index: Int) in played.origin + Double(index) * period }

        return sequence(first: 0) { $0 + 1 }
            .prefix { index in boundary(index) < sound.audible.end }
            .compactMap { index -> MixPath? in
                let start = index == 0 ? min(sound.audible.start, boundary(0)) : boundary(index)
                let repeated = TimeRange(start: start, end: boundary(index + 1))
                guard let cut = heard.intersection(outermost(repeated, through: path.clock)) else { return nil }

                let repeatClock = sound.played.starting(at: boundary(index)).map
                return MixPath(layers: layers, heard: cut, clock: composed(path.clock, repeatClock))
            }
    }

    // A range on the time a path plays, in outermost sequence time.
    private func outermost(
        _ range: TimeRange,
        through clock: TimeMap
    ) -> TimeRange {
        TimeRange(start: clock.sequenceTime(ofClipTime: range.start), end: clock.sequenceTime(ofClipTime: range.end))
    }

    // `outer` followed by `inner`: from outer's sequence time to inner's clip time.
    private func composed(
        _ outer: TimeMap,
        _ inner: TimeMap
    ) -> TimeMap {
        TimeMap(origin: outer.sequenceTime(ofClipTime: inner.origin), in: inner.in, speed: outer.speed * inner.speed)
    }
}
