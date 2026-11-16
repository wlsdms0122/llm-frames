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
    // Past `out`, a looping clip repeats from `in`, a picture holds its last frame, and sound is silent (nil).
    func mediaTime(atSequenceTime time: Double) -> Double? {
        let clipTime = map.clipTime(atSequenceTime: time)
        guard clipTime >= out else { return media.clamped(clipTime) }
        guard !loop else {
            return media.clamped(map.in + (clipTime - map.in).truncatingRemainder(dividingBy: out - map.in))
        }
        guard media.kind != .audio else { return nil }

        return media.clamped(out.nextDown)
    }

    // MARK: - Private
}
