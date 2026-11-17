//
//  SampledFrame.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The frame of a video or a sequence at one time: a frame of the pinned video, or the sequence's display list there.
struct SampledFrame: Equatable, Sendable {
    // MARK: - Property
    let time: Double
    let picture: PictureItemSource

    // MARK: - Initializer
    init(
        time: Double,
        picture: PictureItemSource
    ) {
        self.time = time
        self.picture = picture
    }

    // MARK: - Public
    // MARK: - Private
}
