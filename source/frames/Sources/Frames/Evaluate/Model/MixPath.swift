//
//  MixPath.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One way a sound is heard in the output: the sounds whose gains reach it, outermost first, the range of outermost
// sequence time where all of them are heard, and the clock from outermost sequence time (sequence time) to the time
// played there (clip time), which is media time for a media file and nested sequence time for a nested sequence.
struct MixPath: Equatable, Sendable {
    // MARK: - Property
    let layers: [MixLayer]
    let heard: TimeRange
    let clock: TimeMap

    // MARK: - Initializer
    init(
        layers: [MixLayer],
        heard: TimeRange,
        clock: TimeMap
    ) {
        self.layers = layers
        self.heard = heard
        self.clock = clock
    }

    // MARK: - Public
    // The product of every layer's gain at an outermost sequence time.
    func gain(at time: Double) -> Double {
        layers.reduce(1) { $0 * $1.gain(at: time) }
    }

    // MARK: - Private
}
