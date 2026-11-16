//
//  MixPlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans the sound of a sequence from its audio entries, with no file opened. A sound with media is heard as segments of
// its own, and a nested sequence's sounds are heard through it: their times mapped through its clock, cut to where it
// is heard, and their gains multiplied by its own.
struct MixPlanner: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func mix(of sequence: ResolvedSequence) -> MixPlan {
        let output = MixPath(
            layers: [],
            heard: TimeRange(start: 0, end: sequence.format.duration),
            clock: .sequence
        )

        return MixPlan(segments: sequence.audio.flatMap { sound in
            segments(of: sound, through: [output], fps: sequence.format.fps)
        })
    }

    // MARK: - Private
    // `paths` are in time order, so a sound's segments are, and the sounds of a nested sequence come in entry order.
    private func segments(
        of sound: ResolvedSound,
        through paths: [MixPath],
        fps: Double
    ) -> [MixSegment] {
        let own = paths.flatMap { path in self.paths(of: sound, through: path) }
        guard let media = sound.media else {
            return sound.nested.flatMap { nested in segments(of: nested, through: own, fps: fps) }
        }

        return own.map { path in MixSegment(media: media, path: path, fps: fps) }
    }

    // A sound plays once over where it is audible, or, when it loops, once per repeat, each repeat playing `in` to `out`
    // and the next starting where it ends. Each is cut to where the path is heard.
    private func paths(
        of sound: ResolvedSound,
        through path: MixPath
    ) -> [MixPath] {
        let layers = path.layers + [MixLayer(sound: sound, clock: path.clock)]
        let played = clock(of: sound)
        guard let heard = path.heard.intersection(outermost(sound.audible, through: path.clock)) else { return [] }
        guard sound.loop else {
            return [MixPath(layers: layers, heard: heard, clock: composed(path.clock, played))]
        }

        // Every repeat starts at a boundary worked out the same way, so each starts exactly where the last ends.
        let period = played.sequenceTime(ofClipTime: sound.out) - played.origin
        let boundary = { (index: Int) in played.origin + Double(index) * period }

        return sequence(first: 0) { $0 + 1 }
            .prefix { index in boundary(index) < sound.audible.end }
            .compactMap { index in
                let repeated = TimeRange(start: boundary(index), end: boundary(index + 1))
                guard let cut = heard.intersection(outermost(repeated, through: path.clock)) else { return nil }

                let repeatClock = TimeMap(origin: repeated.start, in: played.in, speed: played.speed)
                return MixPath(layers: layers, heard: cut, clock: composed(path.clock, repeatClock))
            }
    }

    // The clock from the time a sound's instants are on to the media or nested sequence time it plays: `in` plays at
    // `origin`, at `speed`.
    private func clock(of sound: ResolvedSound) -> TimeMap {
        TimeMap(origin: sound.origin, in: sound.in, speed: sound.speed)
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
