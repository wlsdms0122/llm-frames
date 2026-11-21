//
//  SampleProgress.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A transition's progress in a frame (FRAMES-29): `instant`, the progress at its owner's value time, which its motion,
// cover opacity and matte progress are read at, and `frameProgress`, the progress at T, the side of every jump each
// read clamps to and the progress a matte's and a cover's media frame are picked at. Outside a sample of a frame with
// motion blur both are the progress asked for.
struct SampleProgress: Sendable {
    // MARK: - Property
    let instant: Double
    let frameProgress: Double

    // MARK: - Initializer
    init(_ progress: Double) {
        self.init(instant: progress, frameProgress: progress)
    }

    init(
        instant: Double,
        frameProgress: Double
    ) {
        self.instant = instant
        self.frameProgress = frameProgress
    }

    // MARK: - Public
    // MARK: - Private
}
