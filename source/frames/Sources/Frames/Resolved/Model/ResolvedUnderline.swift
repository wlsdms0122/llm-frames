//
//  ResolvedUnderline.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A run's underline: its colour, width and offset as keyframe lists, and its pieces in line order in the text's box,
// each on the baseline.
struct ResolvedUnderline: Equatable, Sendable {
    // MARK: - Property
    let color: TimedValue
    let width: TimedValue
    let offset: TimedValue
    let rects: [UnderlinePiece]

    // MARK: - Initializer
    init(
        color: TimedValue,
        width: TimedValue,
        offset: TimedValue,
        rects: [UnderlinePiece]
    ) {
        self.color = color
        self.width = width
        self.offset = offset
        self.rects = rects
    }

    // MARK: - Public
    // MARK: - Private
}
