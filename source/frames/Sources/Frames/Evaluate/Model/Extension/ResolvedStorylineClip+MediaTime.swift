//
//  ResolvedStorylineClip+MediaTime.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The media time a storyline entry shows at a sequence time: `in` at `start`, at `speed`, on the same line in the
// handles. Pinned media is held to its first and last frame's time, so a decoder is only asked for frames that exist.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func mediaTime(at time: Double) -> Double {
        let mediaTime = TimeMap(origin: start, in: `in`, speed: speed).clipTime(atSequenceTime: time)
        guard case let .pinned(media) = media,
            let first = media.frameTimes.first,
            let last = media.frameTimes.last
        else { return mediaTime }

        return min(max(mediaTime, first), last)
    }

    // MARK: - Private
}
