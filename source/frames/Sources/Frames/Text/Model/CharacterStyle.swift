//
//  CharacterStyle.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The character attributes a run is set at. `families` is its font list. `size` is in output pixels, already
// multiplied by the length scale of the place the text is drawn, `tracking` is in thousandths of an em, and `features`
// are the style's own settings, without `kern`. `isHighlighted` and `isUnderlined` say whether the run's highlight and
// underline pieces are cut; their colours and lengths, like the run's colour, stroke and baseline shift, change no
// glyph's place and are timed by the title planner.
struct CharacterStyle: Equatable, Sendable {
    // MARK: - Property
    let families: [String]
    let weight: FontWeight
    let italic: Bool
    let size: Double
    let tracking: Double
    let isKerned: Bool
    let features: [FontFeature]
    let isHighlighted: Bool
    let isUnderlined: Bool

    // MARK: - Initializer
    init(
        families: [String],
        weight: FontWeight,
        italic: Bool = false,
        size: Double,
        tracking: Double = 0,
        isKerned: Bool = true,
        features: [FontFeature] = [],
        isHighlighted: Bool = false,
        isUnderlined: Bool = false
    ) {
        self.families = families
        self.weight = weight
        self.italic = italic
        self.size = size
        self.tracking = tracking
        self.isKerned = isKerned
        self.features = features
        self.isHighlighted = isHighlighted
        self.isUnderlined = isUnderlined
    }

    // MARK: - Public
    // MARK: - Private
}
