//
//  MixPlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans the sound of a sequence without opening a file. A nested sequence's sounds are heard through it: their times
// mapped through its clock, cut to where it is heard, and their gains multiplied by its own.
package struct MixPlanner: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func mix(of sequence: ResolvedSequence) -> MixPlan {
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

        // Every repeat starts at a boundary worked out the same way, so each starts exactly where the last ends. Before
        // the first, a sound a split starts early plays the media before `in`.
        let period = sound.played.naturalLength
        let boundary = { (index: Int) in played.origin + Double(index) * period }
        let leading = sound.audible.start < played.origin
            ? heard.intersection(outermost(TimeRange(start: sound.audible.start, end: played.origin), through: path.clock))
            : nil
        let repeats = sequence(first: 0) { $0 + 1 }
            .prefix { index in boundary(index) < sound.audible.end }
            .compactMap { index -> MixPath? in
                let repeated = TimeRange(start: boundary(index), end: boundary(index + 1))
                guard let cut = heard.intersection(outermost(repeated, through: path.clock)) else { return nil }

                let repeatClock = sound.played.starting(at: repeated.start).map
                return MixPath(layers: layers, heard: cut, clock: composed(path.clock, repeatClock))
            }

        return (leading.map { [MixPath(layers: layers, heard: $0, clock: composed(path.clock, played))] } ?? []) + repeats
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
