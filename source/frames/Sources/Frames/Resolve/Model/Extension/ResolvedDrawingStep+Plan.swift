//
//  ResolvedDrawingStep+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A drawing step with every file it draws pinned, and what drew it named as messages name it.
extension ResolvedDrawingStep {
    // MARK: - Property
    // MARK: - Initializer
    init(
        step: DrawingStep,
        hashes: any FileHashProvider
    ) throws {
        self.init(
            place: step.origin.place.description,
            id: step.origin.id,
            kind: step.origin.kind.label,
            content: try ResolvedDrawingContent(content: step.content, hashes: hashes),
            clip: step.clip
        )
    }

    // MARK: - Public
    // MARK: - Private
}
