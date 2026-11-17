//
//  FoundArea.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// An area as resolve found it, in the pixels of its picture: `rectangle` is what it stands for, padded and cut to the
// picture, and `target` is the area before padding, which a tracker follows. `lines` are the recognised lines it was
// made from, searched at `mediaTime`, and are empty for a rectangle.
struct FoundArea: Equatable, Sendable {
    // MARK: - Property
    let rectangle: Rectangle
    let target: Rectangle
    let mediaTime: Double
    let lines: [RecognisedLine]

    // MARK: - Initializer
    init(
        rectangle: Rectangle,
        target: Rectangle,
        mediaTime: Double,
        lines: [RecognisedLine]
    ) {
        self.rectangle = rectangle
        self.target = target
        self.mediaTime = mediaTime
        self.lines = lines
    }

    // MARK: - Public
    // MARK: - Private
}
