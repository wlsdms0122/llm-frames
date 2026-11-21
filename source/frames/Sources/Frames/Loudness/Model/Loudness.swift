//
//  Loudness.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The measures of the loudness meter over a range of a sound: `integrated`, `momentaryMax` and `shortTermMax` in LUFS,
// `range` in LU, `truePeak` in dBTP and `samplePeak` in dBFS, each nil where the meter gives none.
package struct Loudness: Equatable, Sendable {
    // MARK: - Property
    package let integrated: Double?
    package let range: Double?
    package let momentaryMax: Double?
    package let shortTermMax: Double?
    package let truePeak: Double?
    package let samplePeak: Double?

    // MARK: - Initializer
    package init(
        integrated: Double?,
        range: Double?,
        momentaryMax: Double?,
        shortTermMax: Double?,
        truePeak: Double?,
        samplePeak: Double?
    ) {
        self.integrated = integrated
        self.range = range
        self.momentaryMax = momentaryMax
        self.shortTermMax = shortTermMax
        self.truePeak = truePeak
        self.samplePeak = samplePeak
    }

    // MARK: - Public
    // Each measure as it is written: rounded to the nearest hundredth, halves toward positive infinity.
    package func rounded() -> Loudness {
        let round = { (value: Double?) in value.map { ($0 * 100 + 0.5).rounded(.down) / 100 } }

        return Loudness(
            integrated: round(integrated),
            range: round(range),
            momentaryMax: round(momentaryMax),
            shortTermMax: round(shortTermMax),
            truePeak: round(truePeak),
            samplePeak: round(samplePeak)
        )
    }

    // MARK: - Private
}
