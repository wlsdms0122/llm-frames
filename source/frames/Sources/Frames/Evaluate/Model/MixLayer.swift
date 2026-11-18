//
//  MixLayer.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A sound whose gain and pan reach a segment, with the clock from outermost sequence time (sequence time) to the time
// its instants are on (clip time).
struct MixLayer: Equatable, Sendable {
    // MARK: - Property
    let sound: ResolvedSound
    let clock: TimeMap

    // Where the sound's gain bends and moves, in outermost sequence time.
    var gainTimes: EnvelopeTimes {
        sound.gainTimes.mapped(through: clock)
    }

    // Where the sound's pan bends and moves, in outermost sequence time.
    var panTimes: EnvelopeTimes {
        EnvelopeTimes(keyframes: sound.pan).mapped(through: clock)
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

    // The sound's pan at an outermost sequence time, from its keyframes with their eases.
    func pan(at time: Double) -> Double {
        sound.pan.value(at: clock.clipTime(atSequenceTime: time))
    }

    // MARK: - Private
}
