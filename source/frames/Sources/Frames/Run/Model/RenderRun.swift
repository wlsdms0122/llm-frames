//
//  RenderRun.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a render wrote: its frames, 1 for a PNG, and how the encoder wrote each file, the output first and then the
// delivery.
package struct RenderRun: Equatable, Sendable {
    // MARK: - Property
    package let frames: Int
    package let files: [FileEncoding]

    // MARK: - Initializer
    package init(
        frames: Int,
        files: [FileEncoding]
    ) {
        self.frames = frames
        self.files = files
    }

    // MARK: - Public
    // MARK: - Private
}
