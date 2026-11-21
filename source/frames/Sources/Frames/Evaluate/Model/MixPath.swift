//
//  MixPath.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One way a sound is heard in the output. `layers` are the sound and the compound clips that hold it, outermost first
// and the sound last. Every layer's pan reaches it, since pan comes before a bus's sum, and only the sound's own gain,
// since a compound clip's level is on its bus. `heard` is where all of them are heard, in outermost sequence time.
// `clock` maps outermost sequence time to the time played there, media time for a media file and nested sequence time
// for a nested sequence.
struct MixPath: Equatable, Sendable {
    // MARK: - Property
    let layers: [MixLayer]
    let heard: TimeRange
    let clock: TimeMap

    // Where the sound's own gain bends and moves.
    var gainTimes: EnvelopeTimes {
        layers.last?.gainTimes ?? EnvelopeTimes(breakpoints: [], moving: [])
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
    // The sound's own gain at an outermost sequence time.
    func gain(at time: Double) -> Double {
        layers.last?.gain(at: time) ?? 1
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
