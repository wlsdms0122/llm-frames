//
//  ResolvedSound+Gain.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Times are on the clock the sound's instants are on.
extension ResolvedSound {
    // MARK: - Property
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
    private func ramp(
        at time: Double,
        from silent: Double,
        to full: Double
    ) -> Double {
        min(max((time - silent) / (full - silent), 0), 1)
    }

    private func progress(
        at time: Double,
        through crossfade: Crossfade
    ) -> Double {
        ramp(at: time, from: crossfade.range.start, to: crossfade.range.end)
    }
}
