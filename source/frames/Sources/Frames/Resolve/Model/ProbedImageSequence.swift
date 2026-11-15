//
//  ProbedImageSequence.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The probed facts of an image sequence directory: how many frames it holds and the size of their picture.
struct ProbedImageSequence: Equatable, Sendable {
    // MARK: - Property
    let frameCount: Int
    let size: Size

    // MARK: - Initializer
    init(
        frameCount: Int,
        size: Size
    ) {
        self.frameCount = frameCount
        self.size = size
    }

    // MARK: - Public
    // MARK: - Private
}
