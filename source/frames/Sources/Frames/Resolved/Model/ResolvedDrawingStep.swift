//
//  ResolvedDrawingStep.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One drawing step of a picture, clipped to `clip`, the canvas it was drawn on. `place`, `id` and `kind` name what drew
// it as messages name it: an operation, the source picture, the layout, its banner or a layout item.
struct ResolvedDrawingStep: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let kind: String
    let content: ResolvedDrawingContent
    let clip: Rectangle

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        kind: String,
        content: ResolvedDrawingContent,
        clip: Rectangle
    ) {
        self.place = place
        self.id = id
        self.kind = kind
        self.content = content
        self.clip = clip
    }

    // MARK: - Public
    // MARK: - Private
}
