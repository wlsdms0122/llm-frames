//
//  ResolvedSound.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A source of sound: its pinned media, or nil for a nested sequence whose sounds are `nested`, on their own clock. It
// plays its played range over `start` to `end` in sequence time, and is heard only over `audible`. The range's
// `origin` need not be `start`, as when tracking narrowed its clip's window.
// `volume` and `pan` are in sequence time, `fadeIn` and `fadeOut` are the ranges it ramps from and to 0 over, and
// `incoming` and `outgoing` the transitions it crossfades over.
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
    let pan: [Keyframe<Double>]
    let fadeIn: TimeRange?
    let fadeOut: TimeRange?
    let incoming: Crossfade?
    let outgoing: Crossfade?

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
        pan: [Keyframe<Double>],
        fadeIn: TimeRange?,
        fadeOut: TimeRange?,
        incoming: Crossfade?,
        outgoing: Crossfade?
    ) {
        self.place = place
        self.media = media
        self.nested = nested
        self.played = played
        self.start = start
        self.end = end
        self.audible = audible
        self.volume = volume
        self.pan = pan
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.incoming = incoming
        self.outgoing = outgoing
    }

    // MARK: - Public
    // MARK: - Private
}
