//
//  EnvelopePoint.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A point of a gain envelope: the gain at a sequence time.
struct EnvelopePoint: Equatable, Sendable {
    // MARK: - Property
    let time: Double
    let gain: Double

    // MARK: - Initializer
    init(
        time: Double,
        gain: Double
    ) {
        self.time = time
        self.gain = gain
    }

    // MARK: - Public
    // MARK: - Private
}
