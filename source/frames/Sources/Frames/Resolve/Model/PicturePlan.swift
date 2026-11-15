//
//  PicturePlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve decided for an image or layout document: its final size and its drawing steps in operation order, in
// output pixels. Evaluating it at any time gives the same display list.
struct PicturePlan: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let steps: [DrawingStep]

    // MARK: - Initializer
    init(
        size: Size,
        steps: [DrawingStep]
    ) {
        self.size = size
        self.steps = steps
    }

    // MARK: - Public
    // MARK: - Private
}
