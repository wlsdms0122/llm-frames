//
//  EnvelopePoint.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A point of a gain envelope: the gain at a sequence time.
package struct EnvelopePoint: Equatable, Sendable {
    // MARK: - Property
    package let time: Double
    package let gain: Double

    // MARK: - Initializer
    package init(
        time: Double,
        gain: Double
    ) {
        self.time = time
        self.gain = gain
    }

    // MARK: - Public
    // MARK: - Private
}
