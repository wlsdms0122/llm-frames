//
//  Shutter.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A sequence's shutter, its `format.motionBlur`: `angle` is how long the shutter is open in degrees of a frame, above
// 0 and at most 720, `phase` when it opens in degrees before the frame's instant, from -`angle` to 0, and
// `samplesPerFrame` how many pictures of a frame its exposure is the mean of, from 2 to 256.
struct Shutter: Equatable, Sendable {
    // MARK: - Property
    static let `default` = Shutter(angle: 180, phase: 0, samplesPerFrame: 16)
    static let angles = NumberDomain.leftOpen(0, 720)
    static let samples = NumberDomain.range(2...256)

    let angle: Double
    let phase: Double
    let samplesPerFrame: Int

    // MARK: - Initializer
    init(
        angle: Double,
        phase: Double,
        samplesPerFrame: Int
    ) {
        self.angle = angle
        self.phase = phase
        self.samplesPerFrame = samplesPerFrame
    }

    // MARK: - Public
    // The phases an angle above 0 takes, so the exposure holds the frame's instant.
    static func phases(under angle: Double) -> NumberDomain {
        .range(-angle...0)
    }

    // MARK: - Private
}
