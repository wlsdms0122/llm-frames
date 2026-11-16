//
//  MediaTiming.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// How a timed media clip that is not on the storyline plays: from `in` at the start of its window, at its own speed.
struct MediaTiming: Equatable, Sendable {
    // MARK: - Property
    let media: MediaPlan
    let map: TimeMap
    let out: Double
    let loop: Bool

    // The single-start window: the clip's natural length in sequence seconds.
    var naturalLength: Double {
        (out - map.in) / map.speed
    }

    // MARK: - Initializer
    init(
        media: MediaPlan,
        map: TimeMap,
        out: Double,
        loop: Bool
    ) {
        self.media = media
        self.map = map
        self.out = out
        self.loop = loop
    }

    // MARK: - Public
    // The media time by the clip's time map, within the media's frames. A sound that has ended is silent (nil).
    func mediaTime(atSequenceTime time: Double) -> Double? {
        guard media.kind != .audio || !map.hasEnded(atSequenceTime: time, out: out, loop: loop) else { return nil }

        return media.clamped(map.clipTime(atSequenceTime: time, out: out, loop: loop))
    }

    // MARK: - Private
}
