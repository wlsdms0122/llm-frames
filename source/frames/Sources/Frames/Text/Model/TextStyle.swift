//
//  TextStyle.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A theme style as resolve sets text in it: colours as values and lengths in output pixels, already multiplied by
// the length scale of the place the text is drawn. `families` is the theme's font list, and `pack` the pack the theme
// that wrote it is in, whose fonts come before the machine's.
struct TextStyle: Equatable, Sendable {
    // MARK: - Property
    let families: [String]
    let pack: String?
    let size: Double
    let weight: FontWeight
    let color: Color
    let emphasis: Color
    let lineHeight: Double
    let stroke: TextStroke?
    let background: TextBackground?
    let align: TextAlignment
    let isOneLine: Bool

    // MARK: - Initializer
    init(
        families: [String],
        pack: String?,
        size: Double,
        weight: FontWeight,
        color: Color,
        emphasis: Color,
        lineHeight: Double,
        stroke: TextStroke?,
        background: TextBackground?,
        align: TextAlignment,
        isOneLine: Bool
    ) {
        self.families = families
        self.pack = pack
        self.size = size
        self.weight = weight
        self.color = color
        self.emphasis = emphasis
        self.lineHeight = lineHeight
        self.stroke = stroke
        self.background = background
        self.align = align
        self.isOneLine = isOneLine
    }

    // MARK: - Public
    // MARK: - Private
}
