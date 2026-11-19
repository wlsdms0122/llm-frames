//
//  MixSegment+Path.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

extension MixSegment {
    // MARK: - Property
    // MARK: - Initializer
    init(
        media: PinnedMedia,
        path: MixPath,
        fps: Double
    ) {
        let heard = path.heard
        // Only the media's own sound takes an audio filter; the layers outside it are compound clips, which take none.
        let filter: [MixFilterEntry] = path.layers.last.map { layer in
            guard case let .list(entries) = layer.sound.audioFilter else { return [] }

            let sampler = MixValueSampler(clock: layer.clock, heard: heard, fps: fps)
            return entries.compactMap { MixFilterEntry(timed: $0, sampler: sampler) }
        } ?? []

        self.init(
            media: media,
            mediaStart: path.clock.clipTime(atSequenceTime: heard.start),
            speed: path.clock.speed,
            start: heard.start,
            end: heard.end,
            filter: filter,
            envelope: path.gainTimes.times(over: heard, fps: fps).map { EnvelopePoint(time: $0, value: path.gain(at: $0)) },
            pan: path.panTimes.times(over: heard, fps: fps).map { EnvelopePoint(time: $0, value: path.pan(at: $0)) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
