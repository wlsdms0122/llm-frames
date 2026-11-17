//
//  DrawingStep.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One drawing step of a picture, drawn by `origin` and clipped to `clip`, the canvas it was drawn on as later canvas
// operations left it.
struct DrawingStep: Equatable, Sendable {
    // MARK: - Property
    let origin: DrawingOrigin
    let content: DrawingContent
    let clip: Rectangle

    // MARK: - Initializer
    init(
        origin: DrawingOrigin,
        content: DrawingContent,
        clip: Rectangle
    ) {
        self.origin = origin
        self.content = content
        self.clip = clip
    }

    // MARK: - Public
    // MARK: - Private
}
