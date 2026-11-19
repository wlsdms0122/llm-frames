//
//  GlyphDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreText
import Frames

// Draws a glyphs item in its text's own box: the background, then every run's highlight rectangles in run order, then
// every run's underline rectangles, then the outline of every glyph of every run with a stroke, then every glyph's fill,
// so no stroke covers a fill. An item of a layer draws only that step and no background. Glyphs are drawn at their
// written baseline origins and shaped no further. A run's stroke width is in output pixels, so it is drawn at that width
// along the outlines carried by `transform`, and a transform that scales its axes apart does not stretch it.
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
        let draws = { (layer: GlyphLayer) in item.layer == nil || item.layer == layer }

        if item.layer == nil, let background = item.background {
            context.addPath(PathOutline(.rect(background.rectangle, radius: background.radius)).path)
            context.setFillColor(background.color.cgColor)
            context.fillPath()
        }
        for run in item.runs where draws(.highlights) {
            guard let highlight = run.highlight else { continue }

            fill(highlight.rects, radius: highlight.radius, color: highlight.color, bands: highlight.bands, in: context)
        }
        for run in item.runs where draws(.underlines) {
            guard let underline = run.underline else { continue }

            fill(underline.rects, radius: 0, color: underline.color, bands: underline.bands, in: context)
        }
        guard draws(.strokes) || draws(.fills) else { return }

        let runs = try item.runs.map { run in
            (run: run, font: try fonts.font(file: run.font.path, face: run.face, size: run.size))
        }
        let strokes = item.runs.compactMap(\.stroke).reduce(into: [TextStroke]()) { strokes, stroke in
            guard stroke.width > 0, !strokes.contains(stroke) else { return }

            strokes.append(stroke)
        }
        let back = transform.inverse
        for stroke in strokes where draws(.strokes) {
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
                strokingWithWidth: CGFloat(stroke.width),
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            guard let placed = band?.copy(using: &matrix) else { continue }

            context.addPath(placed)
            context.setFillColor(stroke.color.cgColor)
            context.fillPath(using: .winding)
        }

        for (run, font) in runs where draws(.fills) {
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
    // Each rectangle is drawn whole and cut to its band, the one at its index, where there are bands. A band's end
    // inside the rectangle, where two units' parts meet, is cut aliased on the nearest pixel edge, so each pixel on it
    // goes whole to one part and no seam shows between them: an aliased clip whose edge crosses a pixel takes that pixel
    // on both sides. An end at the rectangle's own edge cuts nothing, keeping that edge antialiased.
    private func fill(
        _ rects: [Rectangle],
        radius: Double,
        color: Color,
        bands: [ClosedRange<Double>]?,
        in context: CGContext
    ) {
        for (index, rect) in rects.enumerated() {
            context.saveGState()
            if let bands, index < bands.count {
                let band = bands[index]
                let margin = rect.width + rect.height
                let start = band.lowerBound > rect.x
                    ? pixelEdge(near: band.lowerBound, y: rect.y, in: context)
                    : rect.x - margin
                let right = rect.x + rect.width
                let end = band.upperBound < right
                    ? pixelEdge(near: band.upperBound, y: rect.y, in: context)
                    : right + margin
                context.setShouldAntialias(false)
                context.clip(to: CGRect(x: start, y: rect.y - margin, width: end - start, height: rect.height + margin * 2))
                context.setShouldAntialias(true)
            }
            context.addPath(PathOutline(.rect(rect, radius: radius)).path)
            context.setFillColor(color.cgColor)
            context.fillPath()
            context.restoreGState()
        }
    }

    private func pixelEdge(
        near x: Double,
        y: Double,
        in context: CGContext
    ) -> Double {
        let device = context.convertToDeviceSpace(CGPoint(x: x, y: y))

        return context.convertToUserSpace(CGPoint(x: device.x.rounded(), y: device.y)).x
    }
}
