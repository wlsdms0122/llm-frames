//
//  TrackSource.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The media a clip's track follows (FRAMES-12): the place of the clip whose video or image sequence it is, its file,
// the clock that gives the media time it shows at a sequence time, and the sequence range the track is needed over,
// where the clip is drawn or, for a clip that follows a storyline clip's media, where that storyline clip is drawn.
struct TrackSource: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let file: MediaFile
    let clock: MediaClock
    let drawn: TimeRange

    // MARK: - Initializer
    init(
        place: Place,
        file: MediaFile,
        clock: MediaClock,
        drawn: TimeRange
    ) {
        self.place = place
        self.file = file
        self.clock = clock
        self.drawn = drawn
    }

    // MARK: - Public
    // MARK: - Private
}
