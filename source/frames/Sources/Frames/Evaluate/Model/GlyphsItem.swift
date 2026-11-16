//
//  GlyphsItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Shaped glyphs with their outline and the box behind them, in the text's own box of `size`.
package struct GlyphsItem: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let runs: [ResolvedGlyphRun]
    package let stroke: TextStroke?
    package let background: GlyphBackground?

    // MARK: - Initializer
    package init(
        size: Size,
        runs: [ResolvedGlyphRun],
        stroke: TextStroke?,
        background: GlyphBackground?
    ) {
        self.size = size
        self.runs = runs
        self.stroke = stroke
        self.background = background
    }

    // Shaped text in its own box. Its background fills the whole box, which holds the background's padding.
    init(text: ResolvedText) {
        self.init(
            size: text.size,
            runs: text.runs,
            stroke: text.stroke,
            background: text.background.map { background in
                GlyphBackground(
                    rectangle: Rectangle(x: 0, y: 0, width: text.size.width, height: text.size.height),
                    radius: background.radius,
                    color: background.color
                )
            }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
