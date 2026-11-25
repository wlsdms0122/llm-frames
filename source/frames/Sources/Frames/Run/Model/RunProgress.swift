//
//  RunProgress.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How far a run has drawn: `frame` frames drawn and handed to the encoder of the run's `frames`, `seconds` after the
// run began.
package struct RunProgress: Equatable, Sendable {
    // MARK: - Property
    package let frame: Int
    package let frames: Int
    package let seconds: Double

    // MARK: - Initializer
    package init(
        frame: Int,
        frames: Int,
        seconds: Double
    ) {
        self.frame = frame
        self.frames = frames
        self.seconds = seconds
    }

    // MARK: - Public
    // MARK: - Private
}
