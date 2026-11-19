//
//  MixSegment+Envelope.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The gain and the pan the envelopes give sample by sample, as `EnvelopeCursor` reads them. Sample n is at sequence
// time n / `sampleRate`.
extension MixSegment {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The gain at each output sample of `samples`, 1 where the envelope has no points.
    package func gains(
        atSamples samples: Range<Int>,
        sampleRate: Double
    ) -> [Float] {
        values(of: envelope, atSamples: samples, sampleRate: sampleRate, empty: 1)
    }

    // The pan at each output sample of `samples`, the centre where the pan envelope has no points.
    package func pans(
        atSamples samples: Range<Int>,
        sampleRate: Double
    ) -> [Float] {
        values(of: pan, atSamples: samples, sampleRate: sampleRate, empty: 0)
    }

    // MARK: - Private
    private func values(
        of points: [EnvelopePoint],
        atSamples samples: Range<Int>,
        sampleRate: Double,
        empty: Float
    ) -> [Float] {
        guard !points.isEmpty else { return Array(repeating: empty, count: samples.count) }
        var cursor = EnvelopeCursor(points: points)

        return samples.map { Float(cursor.value(at: Double($0) / sampleRate)) }
    }
}
