//
//  EnvelopePoint.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A point of an envelope: its value, a gain or a pan, at a sequence time.
package struct EnvelopePoint: Equatable, Sendable {
    // MARK: - Property
    package let time: Double
    package let value: Double

    // MARK: - Initializer
    package init(
        time: Double,
        value: Double
    ) {
        self.time = time
        self.value = value
    }

    // MARK: - Public
    // MARK: - Private
}
