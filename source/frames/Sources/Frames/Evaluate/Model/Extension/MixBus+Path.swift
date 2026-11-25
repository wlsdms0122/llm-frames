//
//  MixBus+Path.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

extension MixBus {
    // MARK: - Property
    // MARK: - Initializer
    // The bus a compound clip's path plays. Its chain is `nestedAudioFilter`, the nested sequence's entries, on the
    // path's clock, which maps outermost sequence time to nested sequence time through the compound clip's speed and
    // the repeat's start, then the compound clip's own on the clock its instants are on. Its level is the compound
    // clip's gain alone.
    init(
        path: MixPath,
        segments: [MixSegment],
        buses: [MixBus],
        nestedAudioFilter: TimedValue,
        fps: Double
    ) {
        let heard = path.heard
        let filter = path.layers.last.map { layer in
            MixFilterEntry.entries(
                of: nestedAudioFilter,
                sampler: MixValueSampler(clock: path.clock, heard: heard, fps: fps)
            ) + MixFilterEntry.entries(
                of: layer.sound.audioFilter,
                sampler: MixValueSampler(clock: layer.clock, heard: heard, fps: fps)
            )
        } ?? []

        self.init(
            start: heard.start,
            end: heard.end,
            segments: segments,
            buses: buses,
            filter: filter,
            envelope: path.gainTimes.times(over: heard, fps: fps).map { EnvelopePoint(time: $0, value: path.gain(at: $0)) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
