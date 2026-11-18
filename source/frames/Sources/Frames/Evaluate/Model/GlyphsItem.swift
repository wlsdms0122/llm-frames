//
//  GlyphsItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Shaped glyphs, each run with its own outline, and the box behind them, in the text's own box of `size`.
package struct GlyphsItem: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let runs: [ResolvedGlyphRun]
    package let background: GlyphBackground?

    // MARK: - Initializer
    package init(
        size: Size,
        runs: [ResolvedGlyphRun],
        background: GlyphBackground?
    ) {
        self.size = size
        self.runs = runs
        self.background = background
    }

    // Shaped text in its own box. Its background fills the whole box, which holds the background's padding.
    init(text: ResolvedText) {
        self.init(
            size: text.size,
            runs: text.runs,
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
    // What the item draws in its own box (FRAMES-14): the box, which holds its background, grown by half its widest
    // stroke, since a stroke is centred on outlines that reach the box's edges.
    package func drawnBounds() -> Rectangle {
        let half = (runs.compactMap(\.stroke).map(\.width).max() ?? 0) / 2

        return Rectangle(x: 0, y: 0, width: size.width, height: size.height).grown(by: half)
    }

    // MARK: - Private
}
