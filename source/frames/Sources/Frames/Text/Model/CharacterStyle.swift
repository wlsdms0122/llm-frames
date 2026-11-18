//
//  CharacterStyle.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A theme style's character attributes. `families` is the theme's font list and `pack` the pack of the theme that wrote
// it, whose fonts come before the machine's. `size` and the stroke width are in output pixels, already multiplied by
// the length scale of the place the text is drawn.
struct CharacterStyle: Equatable, Sendable {
    // MARK: - Property
    let families: [String]
    let pack: String?
    let weight: FontWeight
    let size: Double
    let color: Color
    let stroke: TextStroke?

    // MARK: - Initializer
    init(
        families: [String],
        pack: String?,
        weight: FontWeight,
        size: Double,
        color: Color,
        stroke: TextStroke?
    ) {
        self.families = families
        self.pack = pack
        self.weight = weight
        self.size = size
        self.color = color
        self.stroke = stroke
    }

    // MARK: - Public
    // MARK: - Private
}
