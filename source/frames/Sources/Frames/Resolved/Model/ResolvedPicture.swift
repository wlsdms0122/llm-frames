//
//  ResolvedPicture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A resolved image or layout document: its kind (`image` or `layout`), its final size, and its drawing steps in
// operation order, in output pixels.
package struct ResolvedPicture: Equatable, Sendable {
    // MARK: - Property
    let kind: String
    let size: Size
    let steps: [ResolvedDrawingStep]

    // MARK: - Initializer
    init(
        kind: String,
        size: Size,
        steps: [ResolvedDrawingStep]
    ) {
        self.kind = kind
        self.size = size
        self.steps = steps
    }

    // MARK: - Public
    // MARK: - Private
}
