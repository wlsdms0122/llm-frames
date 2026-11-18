//
//  ResolvedSound+Gain.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The gain of a sound on the clock its instants are on: its volume with its eases, times its fades from and to 0, each
// linear over its range, and times its transition crossfades on their curves (FRAMES-13).
extension ResolvedSound {
    // MARK: - Property
    // Where the gain bends: every volume keyframe and both ends of every fade and crossfade. It moves between volume
    // keyframes of different values and over every fade and crossfade.
    var gainTimes: EnvelopeTimes {
        let ramps = [fadeIn, fadeOut, incoming?.range, outgoing?.range].compactMap { $0 }

        return EnvelopeTimes(keyframes: volume).merged(with: EnvelopeTimes(ramps: ramps))
    }

    // MARK: - Initializer
    // MARK: - Public
    func gain(at time: Double) -> Double {
        let level = volume.value(at: time)
        let fades = [
            fadeIn.map { ramp(at: time, from: $0.start, to: $0.end) },
            fadeOut.map { ramp(at: time, from: $0.end, to: $0.start) }
        ]
        let crossfades = [
            incoming.map { $0.curve.gains(at: progress(at: time, through: $0)).incoming },
            outgoing.map { $0.curve.gains(at: progress(at: time, through: $0)).outgoing }
        ]

        return (fades + crossfades).compactMap { $0 }.reduce(level, *)
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

    // u, the progress through a crossfade at an even pace: 0 at its start and before, 1 at its end and after.
    private func progress(
        at time: Double,
        through crossfade: Crossfade
    ) -> Double {
        ramp(at: time, from: crossfade.range.start, to: crossfade.range.end)
    }
}
