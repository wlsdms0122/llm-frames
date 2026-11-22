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
// written origins and shaped no further, each narrowed about its origin along its own horizontal axis by its run's
// horizontal scale and then, in a sideways run, turned 90 degrees clockwise about it, and bands cut rectangles along the
// item's inline axis. A run's stroke width is in output pixels, so it is drawn at that width along the outlines carried
// by `transform`, narrowed ones among them, and a transform that scales its axes apart does not stretch it.
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
        let draws = { (layer: GlyphLayer) in item.unit.map { $0.layer == layer } ?? true }

        if item.unit == nil, let background = item.background {
            context.addPath(PathOutline(.rect(background.rectangle, radius: background.radius)).path)
            context.setFillColor(background.color.cgColor)
            context.fillPath()
        }
        for run in item.runs where draws(.highlights) {
            guard let highlight = run.highlight else { continue }

            fill(
                highlight.rects,
                radius: highlight.radius,
                color: highlight.color,
                bands: highlight.bands,
                writingMode: item.writingMode,
                in: context
            )
        }
        for run in item.runs where draws(.underlines) {
            guard let underline = run.underline else { continue }

            fill(
                underline.rects,
                radius: 0,
                color: underline.color,
                bands: underline.bands,
                writingMode: item.writingMode,
                in: context
            )
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
                let space = glyphSpace(of: run)
                for glyph in run.glyphs {
                    var placement = CGAffineTransform(
                        a: space.a,
                        b: space.b,
                        c: space.c,
                        d: space.d,
                        tx: glyph.x,
                        ty: glyph.y
                    )
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
            let space = glyphSpace(of: run)
            let origins = space.inverted()
            let positions = run.glyphs.map { CGPoint(x: $0.x, y: $0.y).applying(origins) }

            context.saveGState()
            context.concatenate(space)
            context.setFillColor(run.color.cgColor)
            CTFontDrawGlyphs(font, glyphs, positions, glyphs.count, context)
            context.restoreGState()
        }
    }

    // MARK: - Private
    // The map from a glyph's own space, y up, to the item's, y down: narrowed along its own x by the run's horizontal
    // scale, then turned 90 degrees clockwise in a sideways run, so its ascenders point right.
    private func glyphSpace(of run: DrawnGlyphRun) -> CGAffineTransform {
        let narrowing = CGAffineTransform(scaleX: CGFloat(run.horizontalScale), y: 1)
        let turn = run.isSideways
            ? CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
            : CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)

        return narrowing.concatenating(turn)
    }

    // Each rectangle is drawn whole and cut to its band, the one at its index, where there are bands, a span along the
    // inline axis of `writingMode`. A band's end inside the rectangle, where two units' parts meet, is cut aliased on
    // the nearest pixel edge, so each pixel on it goes whole to one part and no seam shows between them: an aliased clip
    // whose edge crosses a pixel takes that pixel on both sides. An end at the rectangle's own edge cuts nothing,
    // keeping that edge antialiased.
    private func fill(
        _ rects: [Rectangle],
        radius: Double,
        color: Color,
        bands: [ClosedRange<Double>]?,
        writingMode: WritingMode,
        in context: CGContext
    ) {
        for (index, drawn) in rects.enumerated() {
            context.saveGState()
            if let band = bands?[index] {
                let rect = writingMode.turned(drawn)
                let margin = rect.width + rect.height
                let start = band.lowerBound > rect.x
                    ? pixelEdge(near: band.lowerBound, block: rect.y, writingMode: writingMode, in: context)
                    : rect.x - margin
                let right = rect.x + rect.width
                let end = band.upperBound < right
                    ? pixelEdge(near: band.upperBound, block: rect.y, writingMode: writingMode, in: context)
                    : right + margin
                let clip = writingMode.turned(
                    Rectangle(x: start, y: rect.y - margin, width: end - start, height: rect.height + margin * 2)
                )
                context.setShouldAntialias(false)
                context.clip(to: CGRect(x: clip.x, y: clip.y, width: clip.width, height: clip.height))
                context.setShouldAntialias(true)
            }
            context.addPath(PathOutline(.rect(drawn, radius: radius)).path)
            context.setFillColor(color.cgColor)
            context.fillPath()
            context.restoreGState()
        }
    }

    // The inline coordinate nearest `along` of a pixel edge, in line coordinates of `writingMode` at `block`.
    private func pixelEdge(
        near along: Double,
        block: Double,
        writingMode: WritingMode,
        in context: CGContext
    ) -> Double {
        let point = writingMode.turned(Point(x: along, y: block))
        let device = context.convertToDeviceSpace(CGPoint(x: point.x, y: point.y))
        let line = writingMode.turned(Point(x: device.x, y: device.y))
        let edge = writingMode.turned(Point(x: line.x.rounded(), y: line.y))
        let user = context.convertToUserSpace(CGPoint(x: edge.x, y: edge.y))

        return writingMode.turned(Point(x: user.x, y: user.y)).x
    }
}
