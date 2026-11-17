//
//  SampledFrames.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Frames taken from one video or sequence in time order, every one `size` pixels.
struct SampledFrames: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let frames: [SampledFrame]

    // MARK: - Initializer
    init(
        size: Size,
        frames: [SampledFrame]
    ) {
        self.size = size
        self.frames = frames
    }

    // MARK: - Public
    // MARK: - Private
}
