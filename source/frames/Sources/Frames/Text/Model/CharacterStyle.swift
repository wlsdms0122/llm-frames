//
//  CharacterStyle.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A theme style's character attributes. `families` is its font list. `size`, `baselineShift` and the lengths of the stroke, highlight and
// underline are in output pixels, already multiplied by the length scale of the place the text is drawn. `tracking`
// is in thousandths of an em, and `features` are the style's own settings, without `kern`.
struct CharacterStyle: Equatable, Sendable {
    // MARK: - Property
    let families: [String]
    let weight: FontWeight
    let italic: Bool
    let size: Double
    let tracking: Double
    let isKerned: Bool
    let features: [FontFeature]
    let baselineShift: Double
    let color: Color
    let stroke: TextStroke?
    let highlight: TextBackground?
    let underline: TextUnderline?

    // MARK: - Initializer
    init(
        families: [String],
        weight: FontWeight,
        italic: Bool = false,
        size: Double,
        tracking: Double = 0,
        isKerned: Bool = true,
        features: [FontFeature] = [],
        baselineShift: Double = 0,
        color: Color,
        stroke: TextStroke?,
        highlight: TextBackground? = nil,
        underline: TextUnderline? = nil
    ) {
        self.families = families
        self.weight = weight
        self.italic = italic
        self.size = size
        self.tracking = tracking
        self.isKerned = isKerned
        self.features = features
        self.baselineShift = baselineShift
        self.color = color
        self.stroke = stroke
        self.highlight = highlight
        self.underline = underline
    }

    // MARK: - Public
    // MARK: - Private
}
