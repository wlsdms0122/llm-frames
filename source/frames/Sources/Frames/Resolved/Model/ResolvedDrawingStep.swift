//
//  ResolvedDrawingStep.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One drawing step of a picture, clipped to `clip`, the canvas it was drawn on.
struct ResolvedDrawingStep: Equatable, Sendable {
    // MARK: - Property
    let content: ResolvedDrawingContent
    let clip: Rectangle

    // MARK: - Initializer
    init(
        content: ResolvedDrawingContent,
        clip: Rectangle
    ) {
        self.content = content
        self.clip = clip
    }

    // MARK: - Public
    // MARK: - Private
}
