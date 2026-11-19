//
//  TextRun.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// `faces` are the faces its text is set in, in the order they are tried, the style's own first. `widestTracking` is
// the largest tracking the run takes over its motion, in thousandths of an em, which lines break at.
// `isSpacedApart` turns the optional ligatures off unless the style's features turn them on, for a run whose tracking
// is not 0 at some instant or whose characters move alone.
struct TextRun: Equatable, Sendable {
    // MARK: - Property
    let text: String
    let style: CharacterStyle
    let faces: [FontFace]
    let widestTracking: Double
    let isSpacedApart: Bool

    // MARK: - Initializer
    init(
        text: String,
        style: CharacterStyle,
        faces: [FontFace],
        widestTracking: Double? = nil,
        isSpacedApart: Bool? = nil
    ) {
        self.text = text
        self.style = style
        self.faces = faces
        self.widestTracking = widestTracking ?? style.tracking
        self.isSpacedApart = isSpacedApart ?? (style.tracking != 0 || (widestTracking ?? 0) != 0)
    }

    // MARK: - Public
    // MARK: - Private
}
