//
//  ProbedImageSequence.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The probed facts of an image sequence directory: the absolute path of each of its frames, every PNG in the directory
// in natural order, and the size of their picture.
struct ProbedImageSequence: Equatable, Sendable {
    // MARK: - Property
    let files: [String]
    let size: Size

    // MARK: - Initializer
    init(
        files: [String],
        size: Size
    ) {
        self.files = files
        self.size = size
    }

    // MARK: - Public
    // MARK: - Private
}
