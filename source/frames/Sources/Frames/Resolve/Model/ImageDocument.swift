//
//  ImageDocument.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// An image document as resolve reads it: its source picture, the media second `time` picks a video's frame at, its own
// theme, and its operations in order.
struct ImageDocument: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let source: MediaSource
    let time: Double
    let theme: ThemeReference?
    let operations: [ImageOperation]

    // MARK: - Initializer
    init(
        place: Place,
        source: MediaSource,
        time: Double,
        theme: ThemeReference?,
        operations: [ImageOperation]
    ) {
        self.place = place
        self.source = source
        self.time = time
        self.theme = theme
        self.operations = operations
    }

    // MARK: - Public
    // MARK: - Private
}
