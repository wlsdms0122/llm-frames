//
//  ResolvedSound.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A source of sound: its pinned media, or nil for a nested sequence whose sounds are `nested`, on their own clock. It
// plays its played range over `start` to `end` in sequence time, and is heard only over `audible`. The range's
// `origin` need not be `start`, as when tracking narrowed its clip's window.
// `volume` is in sequence time, `fadeIn` and `fadeOut` are the ranges it ramps from and to 0 over, and `incoming` and
// `outgoing` the transitions it crossfades over.
struct ResolvedSound: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let media: PinnedMedia?
    let nested: [ResolvedSound]
    let played: PlayedRange
    let start: Double
    let end: Double
    let audible: TimeRange
    let volume: [Keyframe<Double>]
    let fadeIn: TimeRange?
    let fadeOut: TimeRange?
    let incoming: TimeRange?
    let outgoing: TimeRange?

    // MARK: - Initializer
    init(
        place: String,
        media: PinnedMedia?,
        nested: [ResolvedSound],
        played: PlayedRange,
        start: Double,
        end: Double,
        audible: TimeRange,
        volume: [Keyframe<Double>],
        fadeIn: TimeRange?,
        fadeOut: TimeRange?,
        incoming: TimeRange?,
        outgoing: TimeRange?
    ) {
        self.place = place
        self.media = media
        self.nested = nested
        self.played = played
        self.start = start
        self.end = end
        self.audible = audible
        self.volume = volume
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.incoming = incoming
        self.outgoing = outgoing
    }

    // MARK: - Public
    // MARK: - Private
}
