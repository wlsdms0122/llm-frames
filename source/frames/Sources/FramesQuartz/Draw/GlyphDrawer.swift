//
//  GlyphDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreText
import Frames

// Draws a glyphs item in its text's own box: the background, then the outline of every glyph, then every glyph's
// fill, so no stroke covers a fill. Glyphs are drawn at their written baseline origins and shaped no further.
struct GlyphDrawer {
    // MARK: - Property
    private let fonts: FontLibrary

    // MARK: - Initializer
    init(fonts: FontLibrary) {
        self.fonts = fonts
    }

    // MARK: - Public
    func draw(
        _ item: GlyphsItem,
        in context: CGContext
    ) throws {
        if let background = item.background {
            context.addPath(RoundedOutline(rectangle: background.rectangle, radius: background.radius).path)
            context.setFillColor(background.color.cgColor)
            context.fillPath()
        }

        let runs = try item.runs.map { run in
            (run: run, font: try fonts.font(file: run.font.path, face: run.face, size: run.size))
        }
        if let stroke = item.stroke, stroke.width > 0 {
            // One path for every outline of the item, so strokes that cross are drawn once.
            let outlines = CGMutablePath()
            for (run, font) in runs {
                for glyph in run.glyphs {
                    var placement = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: glyph.x, ty: glyph.y)
                    guard let outline = CTFontCreatePathForGlyph(font, CGGlyph(glyph.id), &placement) else { continue }

                    outlines.addPath(outline)
                }
            }

            context.addPath(outlines)
            context.setLineWidth(stroke.width)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.setStrokeColor(stroke.color.cgColor)
            context.strokePath()
        }

        for (run, font) in runs {
            let glyphs = run.glyphs.map { CGGlyph($0.id) }
            // Core Text draws upright in y-up coordinates, so the run is drawn with y turned back up.
            let positions = run.glyphs.map { CGPoint(x: $0.x, y: -$0.y) }

            context.saveGState()
            context.scaleBy(x: 1, y: -1)
            context.setFillColor(run.color.cgColor)
            CTFontDrawGlyphs(font, glyphs, positions, glyphs.count, context)
            context.restoreGState()
        }
    }

    // MARK: - Private
}
