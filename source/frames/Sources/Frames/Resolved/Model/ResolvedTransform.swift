//
//  ResolvedTransform.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A clip placed by its box and moved by `scale` and `rotation`, keyframes in sequence time. `box` is nil for a shape
// placed by its area or its points and for a null placed by its area, whose geometry carries where it goes. Resolve
// gives every title, media clip, and rect, ellipse or null given by `width` and `height` a box; the resolved reader also
// takes a title or a media clip whose `size`, `position` and `anchor` are all null, which then draws nothing.
struct ResolvedTransform: Equatable, Sendable {
    // MARK: - Property
    let box: ResolvedBox?
    let scale: [Keyframe<Scale>]
    let rotation: [Keyframe<Double>]

    // MARK: - Initializer
    init(
        box: ResolvedBox?,
        scale: [Keyframe<Scale>],
        rotation: [Keyframe<Double>]
    ) {
        self.box = box
        self.scale = scale
        self.rotation = rotation
    }

    // MARK: - Public
    // MARK: - Private
}
