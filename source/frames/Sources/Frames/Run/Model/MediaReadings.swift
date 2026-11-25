//
//  MediaReadings.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a decoder has read since it was made: each medium whose pictures it read, by each conversion it read them by, in
// the order it first read each, and its seconds in `decode` and `workingConversion`, sound included in `decode`.
package struct MediaReadings: Equatable, Sendable {
    // MARK: - Property
    package let media: [MediumReading]
    package let seconds: StageTimes

    // MARK: - Initializer
    package init(
        media: [MediumReading],
        seconds: StageTimes
    ) {
        self.media = media
        self.seconds = seconds
    }

    // MARK: - Public
    // MARK: - Private
}
