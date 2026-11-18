//
//  MediaClock.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The media time a timed media clip shows at a sequence time, the one answer every stage asks: its playback's time
// clamped to `frames`, the first and last media time a picture exists at, so a decoder is only asked for frames that
// exist. `frames` is nil for sound, which has no frames to hold.
struct MediaClock: Equatable, Sendable {
    // MARK: - Property
    let playback: MediaPlayback
    let frames: ClosedRange<Double>?

    // MARK: - Initializer
    init(
        playback: MediaPlayback,
        frames: ClosedRange<Double>?
    ) {
        self.playback = playback
        self.frames = frames
    }

    // MARK: - Public
    func mediaTime(atSequenceTime time: Double) -> Double {
        let mediaTime = playback.mediaTime(atSequenceTime: time)
        guard let frames else { return mediaTime }

        return min(max(mediaTime, frames.lowerBound), frames.upperBound)
    }

    // The sequence time its playback reaches a media time at, nil where the playback does not move one way.
    func sequenceTime(ofMediaTime time: Double) -> Double? {
        playback.sequenceTime(ofMediaTime: time)
    }

    // MARK: - Private
}
