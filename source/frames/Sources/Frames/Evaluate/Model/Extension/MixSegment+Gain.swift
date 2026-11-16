//
//  MixSegment+Gain.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The gain the envelope gives sample by sample: straight lines between its points, and the gain of the nearest end
// point outside them.
extension MixSegment {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The gain at each output sample of `samples`, sample n being at sequence time n / `sampleRate`.
    package func gains(
        atSamples samples: Range<Int>,
        sampleRate: Double
    ) -> [Float] {
        guard !envelope.isEmpty else { return Array(repeating: 1, count: samples.count) }
        var point = 0

        return samples.map { sample in
            let time = Double(sample) / sampleRate
            while point + 1 < envelope.count && envelope[point + 1].time <= time {
                point += 1
            }
            let from = envelope[point]
            guard point + 1 < envelope.count, time > from.time else { return Float(from.gain) }
            let to = envelope[point + 1]
            let fraction = (time - from.time) / (to.time - from.time)

            return Float(from.gain + (to.gain - from.gain) * fraction)
        }
    }

    // MARK: - Private
}
