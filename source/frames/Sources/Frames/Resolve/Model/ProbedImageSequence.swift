//
//  ProbedImageSequence.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The probed facts of an image sequence directory: the absolute path of each of its frames, every PNG in the directory
// in natural order, the size of their picture, and whether its first frame carries alpha.
package struct ProbedImageSequence: Equatable, Sendable {
    // MARK: - Property
    package let files: [String]
    package let size: Size
    package let hasAlpha: Bool

    // MARK: - Initializer
    package init(
        files: [String],
        size: Size,
        hasAlpha: Bool = false
    ) {
        self.files = files
        self.size = size
        self.hasAlpha = hasAlpha
    }

    // MARK: - Public
    // MARK: - Private
}
