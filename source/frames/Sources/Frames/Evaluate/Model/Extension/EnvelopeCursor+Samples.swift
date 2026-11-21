//
//  EnvelopeCursor+Samples.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// An envelope read at each output sample of a range, sample n at sequence time n / `sampleRate`.
extension EnvelopeCursor {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The values of `points` at each sample of `samples`, `empty` where there are no points.
    package static func values(
        of points: [EnvelopePoint],
        atSamples samples: Range<Int>,
        sampleRate: Double,
        empty: Float
    ) -> [Float] {
        guard !points.isEmpty else { return Array(repeating: empty, count: samples.count) }
        var cursor = EnvelopeCursor(points: points)

        return samples.map { Float(cursor.value(at: Double($0) / sampleRate)) }
    }

    // MARK: - Private
}
