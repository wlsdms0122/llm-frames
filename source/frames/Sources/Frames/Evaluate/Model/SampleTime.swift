//
//  SampleTime.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The time one owner's values are read at in a frame (FRAMES-29): `instant`, the time they are read at, and
// `frameTime`, T held in the owner's window, the side of every jump each read clamps to. `sample` is the instant of the
// frame they are read in, from which the values of other owners take their own time. Outside a sample of a frame with
// motion blur both times are the time asked for.
struct SampleTime {
    // MARK: - Property
    let instant: Double
    let frameTime: Double
    let sample: SampleInstant

    // MARK: - Initializer
    init(_ time: Double) {
        self.init(instant: time, frameTime: time, sample: SampleInstant(frameTime: time))
    }

    init(
        instant: Double,
        frameTime: Double,
        sample: SampleInstant
    ) {
        self.instant = instant
        self.frameTime = frameTime
        self.sample = sample
    }

    // MARK: - Public
    // MARK: - Private
}
