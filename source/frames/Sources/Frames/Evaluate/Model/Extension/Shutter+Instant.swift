//
//  Shutter+Instant.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A frame's exposure runs from T + P × d to T + (P + A) × d, with d = 1 / (360 × fps) seconds per degree, and its N
// instants are the midpoints of N equal parts of it (FRAMES-29).
extension Shutter {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func instants(
        at frameTime: Double,
        fps: Double
    ) -> [Double] {
        let degree = 1 / (360 * fps)

        return (0 ..< samplesPerFrame).map { index in
            frameTime + (phase + angle * (Double(index) + 0.5) / Double(samplesPerFrame)) * degree
        }
    }

    // MARK: - Private
}
