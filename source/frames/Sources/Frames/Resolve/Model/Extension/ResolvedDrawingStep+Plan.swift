//
//  ResolvedDrawingStep+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A drawing step with every file it draws pinned.
extension ResolvedDrawingStep {
    // MARK: - Property
    // MARK: - Initializer
    init(
        step: DrawingStep,
        hashes: any FileHashProvider
    ) throws {
        self.init(content: try ResolvedDrawingContent(content: step.content, hashes: hashes), clip: step.clip)
    }

    // MARK: - Public
    // MARK: - Private
}
