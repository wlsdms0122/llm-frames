//
//  GlyphDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreText
import Frames

// Draws a glyphs item in its text's own box: the background, then the outline of every glyph of every run with a
// stroke, then every glyph's fill, so no stroke covers a fill. Glyphs are drawn at their written baseline origins and
// shaped no further. A run's stroke width is in the box's pixels at the transform's length factor and is drawn along
// the outlines carried by `transform`, so a transform that scales its axes apart does not stretch it.
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
        carriedBy transform: Frames.AffineTransform,
        in context: CGContext
    ) throws {
        if let background = item.background {
            context.addPath(PathOutline(.rect(background.rectangle, radius: background.radius)).path)
            context.setFillColor(background.color.cgColor)
            context.fillPath()
        }

        let runs = try item.runs.map { run in
            (run: run, font: try fonts.font(file: run.font.path, face: run.face, size: run.size))
        }
        let strokes = item.runs.compactMap(\.stroke).reduce(into: [TextStroke]()) { strokes, stroke in
            guard stroke.width > 0, !strokes.contains(stroke) else { return }

            strokes.append(stroke)
        }
        let back = transform.inverse
        for stroke in strokes {
            guard let back else { break }

            // One path for every outline of the runs in one stroke, a line's and the next's, so strokes that cross
            // are drawn once.
            let outlines = CGMutablePath()
            for (run, font) in runs where run.stroke == stroke {
                for glyph in run.glyphs {
                    var placement = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: glyph.x, ty: glyph.y)
                    guard let outline = CTFontCreatePathForGlyph(font, CGGlyph(glyph.id), &placement) else { continue }

                    outlines.addPath(outline)
                }
            }

            var carry = CGAffineTransform(transform)
            var matrix = CGAffineTransform(back)
            let band = outlines.copy(using: &carry)?.copy(
                strokingWithWidth: CGFloat(stroke.width * transform.lengthFactor),
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            guard let placed = band?.copy(using: &matrix) else { continue }

            context.addPath(placed)
            context.setFillColor(stroke.color.cgColor)
            context.fillPath(using: .winding)
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
