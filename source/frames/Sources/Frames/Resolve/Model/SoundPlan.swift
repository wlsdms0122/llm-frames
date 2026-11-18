//
//  SoundPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A source of sound on the sequence clock: a storyline clip, a connected or sequence media clip, or an audio clip.
// `played` plays its media from `in` at its own speed up to `out`. `range` is where it plays: a clip's visible window or
// a storyline clip's drawn range, cut at the end of the sequence. `audible` is the part of that range where its media
// exists, so a handle that runs out of media is silent outside it. `volume` and `pan` are in sequence time. `fadeIn`
// and `fadeOut` are the ranges its volume ramps from and to 0 over, at the ends of a clip's window or a storyline clip's
// drawn range, and `incoming` and `outgoing` are the transitions it crossfades over. `nested` holds the sounds of a
// compound clip or a sequence document, on its own clock.
struct SoundPlan: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let media: MediaPlan
    let played: PlayedRange
    let range: TimeRange
    let audible: TimeRange
    let volume: PropertyValue<Double>
    let pan: PropertyValue<Double>
    let fadeIn: TimeRange?
    let fadeOut: TimeRange?
    let incoming: Crossfade?
    let outgoing: Crossfade?
    let nested: [SoundPlan]

    // MARK: - Initializer
    init(
        place: Place,
        media: MediaPlan,
        played: PlayedRange,
        range: TimeRange,
        audible: TimeRange,
        volume: PropertyValue<Double>,
        pan: PropertyValue<Double>,
        fadeIn: TimeRange?,
        fadeOut: TimeRange?,
        incoming: Crossfade?,
        outgoing: Crossfade?,
        nested: [SoundPlan]
    ) {
        self.place = place
        self.media = media
        self.played = played
        self.range = range
        self.audible = audible
        self.volume = volume
        self.pan = pan
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.incoming = incoming
        self.outgoing = outgoing
        self.nested = nested
    }

    // MARK: - Public
    // MARK: - Private
}
