//
//  MediaReadings.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a decoder has read since it was made: each medium whose pictures it read, by each conversion it read them by, in
// the order it first read each; its seconds in `decode` and `workingConversion` summed over every thread it read on,
// sound included in `decode`; the part of those seconds it spent reading ahead on threads of its own; and the seconds
// its callers waited on that reading (FRAMES-23 Runs). A decoder that reads nothing ahead has none of either.
package struct MediaReadings: Equatable, Sendable {
    // MARK: - Property
    package let media: [MediumReading]
    package let seconds: StageTimes
    package let readAhead: StageTimes
    package let waiting: Double

    // The seconds the decoder held its callers' threads: its stages run on them and their waiting on its reading ahead.
    package var callerSeconds: Double {
        seconds.renderThreadSeconds - readAhead.renderThreadSeconds + waiting
    }

    // MARK: - Initializer
    package init(
        media: [MediumReading],
        seconds: StageTimes,
        readAhead: StageTimes = StageTimes(),
        waiting: Double = 0
    ) {
        self.media = media
        self.seconds = seconds
        self.readAhead = readAhead
        self.waiting = waiting
    }

    // MARK: - Public
    // MARK: - Private
}
