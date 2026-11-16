//
//  ProbedSound.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The format of a media file's first sound track: its channel count and its sample rate in hertz.
package struct ProbedSound: Equatable, Sendable {
    // MARK: - Property
    package let channels: Int
    package let sampleRate: Double

    // MARK: - Initializer
    package init(
        channels: Int,
        sampleRate: Double
    ) {
        self.channels = channels
        self.sampleRate = sampleRate
    }

    // MARK: - Public
    // MARK: - Private
}
