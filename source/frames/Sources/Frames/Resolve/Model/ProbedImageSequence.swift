//
//  ProbedImageSequence.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The probed facts of an image sequence directory: the absolute path of each of its frames, every PNG in the directory
// in natural order, and the size of their picture.
package struct ProbedImageSequence: Equatable, Sendable {
    // MARK: - Property
    package let files: [String]
    package let size: Size

    // MARK: - Initializer
    package init(
        files: [String],
        size: Size
    ) {
        self.files = files
        self.size = size
    }

    // MARK: - Public
    // MARK: - Private
}
