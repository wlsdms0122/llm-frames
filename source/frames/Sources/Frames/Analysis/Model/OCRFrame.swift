//
//  OCRFrame.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The lines recognised on the frame shown at media time `time`, in reading order.
package struct OCRFrame: Equatable, Sendable {
    // MARK: - Property
    package let time: Double
    package let lines: [RecognisedLine]

    // MARK: - Initializer
    init(
        time: Double,
        lines: [RecognisedLine]
    ) {
        self.time = time
        self.lines = lines
    }

    // MARK: - Public
    // MARK: - Private
}
