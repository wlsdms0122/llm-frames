//
//  MixLayer.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A sound whose gain reaches a segment, with the clock from outermost sequence time (sequence time) to the time its
// instants are on (clip time).
struct MixLayer: Equatable, Sendable {
    // MARK: - Property
    let sound: ResolvedSound
    let clock: TimeMap

    // The sound's breakpoints in outermost sequence time.
    var breakpoints: [Double] {
        sound.breakpoints.map { clock.sequenceTime(ofClipTime: $0) }
    }

    // MARK: - Initializer
    init(
        sound: ResolvedSound,
        clock: TimeMap
    ) {
        self.sound = sound
        self.clock = clock
    }

    // MARK: - Public
    // The sound's gain at an outermost sequence time.
    func gain(at time: Double) -> Double {
        sound.gain(at: clock.clipTime(atSequenceTime: time))
    }

    // MARK: - Private
}
