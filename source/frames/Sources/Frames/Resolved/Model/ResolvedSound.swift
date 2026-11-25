//
//  ResolvedSound.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A source of sound: `source` is what it plays, its pinned media or a nested sequence's sounds. It plays its played
// range over `start` to `end` in sequence time, and is heard only over `audible`. The range's `origin` need not be
// `start`, as when tracking narrowed its clip's window.
// `volume` and `pan` are in sequence time, `fadeIn` and `fadeOut` are the ranges it ramps from and to 0 over, and
// `incoming` and `outgoing` the transitions it crossfades over. `audioFilter` is its own timed list of entries
// `{ops, mix}` in sequence time, a compound clip's own on its bus, `off` for none.
struct ResolvedSound: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let source: ResolvedSoundSource
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
    let audioFilter: TimedValue

    // MARK: - Initializer
    init(
        place: String,
        source: ResolvedSoundSource,
        played: PlayedRange,
        start: Double,
        end: Double,
        audible: TimeRange,
        volume: [Keyframe<Double>],
        pan: [Keyframe<Double>],
        fadeIn: TimeRange?,
        fadeOut: TimeRange?,
        incoming: Crossfade?,
        outgoing: Crossfade?,
        audioFilter: TimedValue = .off
    ) {
        self.place = place
        self.source = source
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
        self.audioFilter = audioFilter
    }

    // MARK: - Public
    // MARK: - Private
}
