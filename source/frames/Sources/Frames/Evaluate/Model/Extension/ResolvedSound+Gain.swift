//
//  ResolvedSound+Gain.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The gain of a sound on the clock its instants are on: its volume with its eases, times its fades from and to 0 and its
// transition crossfades, each linear over its range.
extension ResolvedSound {
    // MARK: - Property
    // The instants where the gain may bend: every volume keyframe and both ends of every fade and crossfade.
    var breakpoints: [Double] {
        let ranges = [fadeIn, fadeOut, incoming, outgoing].compactMap { $0 }
        return volume.map(\.at) + ranges.flatMap { [$0.start, $0.end] }
    }

    // MARK: - Initializer
    // MARK: - Public
    func gain(at time: Double) -> Double {
        let level = KeyframeTrack(keyframes: volume).value(at: time) ?? 1
        let rising = [fadeIn, incoming].compactMap { $0 }.map { ramp(at: time, from: $0.start, to: $0.end) }
        let falling = [fadeOut, outgoing].compactMap { $0 }.map { ramp(at: time, from: $0.end, to: $0.start) }

        return (rising + falling).reduce(level, *)
    }

    // MARK: - Private
    // 0 at `silent`, 1 at `full`, linear between and held outside.
    private func ramp(
        at time: Double,
        from silent: Double,
        to full: Double
    ) -> Double {
        min(max((time - silent) / (full - silent), 0), 1)
    }
}
