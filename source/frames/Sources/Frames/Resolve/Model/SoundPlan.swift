//
//  SoundPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A source of sound on the sequence clock: a storyline clip, a connected or sequence media clip, or an audio clip.
// `map` plays its media from `in` at its own speed up to `out`. `range` is where it plays: a clip's visible window or a
// storyline clip's drawn range, cut at the end of the sequence. `audible` is the part of that range where its media
// exists, so a handle that runs out of media is silent outside it. `volume` is in sequence time. `fadeIn` and `fadeOut`
// are the ranges its volume ramps from and to 0 over, at the ends of a clip's window or a storyline clip's drawn range,
// and `incoming` and `outgoing` are the ranges of the transitions it crossfades over. `nested` holds the sounds of a
// compound clip or a sequence document, on its own clock.
struct SoundPlan: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let media: MediaPlan
    let map: TimeMap
    let out: Double
    let loop: Bool
    let range: TimeRange
    let audible: TimeRange
    let volume: PropertyValue<Double>
    let fadeIn: TimeRange?
    let fadeOut: TimeRange?
    let incoming: TimeRange?
    let outgoing: TimeRange?
    let nested: [SoundPlan]

    var `in`: Double {
        map.in
    }

    var speed: Double {
        map.speed
    }

    // MARK: - Initializer
    init(
        place: Place,
        media: MediaPlan,
        map: TimeMap,
        out: Double,
        loop: Bool,
        range: TimeRange,
        audible: TimeRange,
        volume: PropertyValue<Double>,
        fadeIn: TimeRange?,
        fadeOut: TimeRange?,
        incoming: TimeRange?,
        outgoing: TimeRange?,
        nested: [SoundPlan]
    ) {
        self.place = place
        self.media = media
        self.map = map
        self.out = out
        self.loop = loop
        self.range = range
        self.audible = audible
        self.volume = volume
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.incoming = incoming
        self.outgoing = outgoing
        self.nested = nested
    }

    // MARK: - Public
    // MARK: - Private
}
