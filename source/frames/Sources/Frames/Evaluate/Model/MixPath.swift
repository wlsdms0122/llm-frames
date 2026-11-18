//
//  MixPath.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One way a sound is heard in the output: the sounds whose gains and pans reach it, outermost first, the range of
// outermost sequence time where all of them are heard, and the clock from outermost sequence time (sequence time) to the
// time played there (clip time), which is media time for a media file and nested sequence time for a nested sequence.
struct MixPath: Equatable, Sendable {
    // MARK: - Property
    let layers: [MixLayer]
    let heard: TimeRange
    let clock: TimeMap

    // Where the product of the layers' gains bends and moves.
    var gainTimes: EnvelopeTimes {
        times(of: \.gainTimes)
    }

    // Where the sum of the layers' pans bends and moves.
    var panTimes: EnvelopeTimes {
        times(of: \.panTimes)
    }

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

    // The sum of every layer's pan at an outermost sequence time, cut to -1 and 1, so a compound clip's pan adds to
    // its sounds'.
    func pan(at time: Double) -> Double {
        min(max(layers.reduce(0) { $0 + $1.pan(at: time) }, -1), 1)
    }

    // MARK: - Private
    private func times(of layerTimes: KeyPath<MixLayer, EnvelopeTimes>) -> EnvelopeTimes {
        layers.map { $0[keyPath: layerTimes] }.reduce(EnvelopeTimes(breakpoints: [], moving: [])) { $0.merged(with: $1) }
    }
}
