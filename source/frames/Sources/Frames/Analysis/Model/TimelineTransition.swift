//
//  TimelineTransition.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A storyline clip's incoming transition: its preset and its length after it is cut to what fits.
struct TimelineTransition: Equatable, Sendable {
    // MARK: - Property
    let preset: String
    let seconds: Double

    // MARK: - Initializer
    init(preset: String, seconds: Double) {
        self.preset = preset
        self.seconds = seconds
    }

    // MARK: - Public
    // MARK: - Private
}
