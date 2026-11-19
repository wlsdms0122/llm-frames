//
//  GlyphsItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Shaped glyphs and their background in the text's own box of `size`.
package struct GlyphsItem: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let runs: [DrawnGlyphRun]
    package let background: GlyphBackground?

    // MARK: - Initializer
    package init(
        size: Size,
        runs: [DrawnGlyphRun],
        background: GlyphBackground?
    ) {
        self.size = size
        self.runs = runs
        self.background = background
    }

    // Shaped text in its own box at `time`. Its background fills the whole box, which holds the background's padding.
    init(
        text: ResolvedText,
        at time: Double
    ) {
        self.init(
            size: text.size,
            runs: text.runs.map { run in DrawnGlyphRun(run: run, at: time) },
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
    // The box grown by half the widest stroke, since a stroke is centred on outlines that reach the box's edges.
    package func drawnBounds() -> Rectangle {
        let half = (runs.compactMap(\.stroke).map(\.width).max() ?? 0) / 2

        return Rectangle(x: 0, y: 0, width: size.width, height: size.height).grown(by: half)
    }

    // MARK: - Private
}
