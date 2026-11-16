//
//  Typesetter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Sets text in a style: `**text**` in the emphasis colour, runs shaped by the shaping provider, lines broken by UAX #14
// with words kept whole as `word-break: keep-all` keeps them, at `\n` and at the wrapping width, and placed in a box by
// the style's line height, alignment and background.
struct Typesetter: Sendable {
    // MARK: - Property
    private let shaper: any ShapingProvider
    private let breaker = LineBreaker()

    // MARK: - Initializer
    init(shaper: any ShapingProvider) {
        self.shaper = shaper
    }

    // MARK: - Public
    // `width` is the wrapping width in output pixels, and nil keeps the text on one line, as a label is. A style that
    // keeps its text on one line wraps at no width, and is too wide when it is wider than `width`.
    func layout(
        _ text: String,
        style: TextStyle,
        face: FontFace,
        width: Double?,
        place: Place,
        kind: String
    ) throws -> TextLayout {
        let isOneLine = style.isOneLine || width == nil
        let lines = try paragraphs(of: spans(of: text, style: style)).flatMap { paragraph in
            try self.lines(of: paragraph, face: face, size: style.size, width: isOneLine ? nil : width)
        }
        guard !isOneLine || lines.count == 1 else { throw TextError.lineBreakOnOneLine(place: place, kind: kind) }

        let textWidth = lines.map(\.width).reduce(0, max)
        if isOneLine, let width, textWidth > width {
            throw TextError.tooWide(place: place, kind: kind, width: textWidth, room: width)
        }

        let padding = style.background?.padding ?? Size(width: 0, height: 0)
        let runs = lines.enumerated().flatMap { index, line in
            placed(
                line,
                origin: Point(
                    x: padding.width + alignmentOffset(of: line, in: textWidth, align: style.align),
                    y: padding.height + baseline(of: index, face: face, style: style)
                ),
                size: style.size
            )
        }

        return TextLayout(
            size: Size(
                width: textWidth + padding.width * 2,
                height: Double(lines.count) * style.lineHeight + padding.height * 2
            ),
            lineCount: lines.count,
            runs: runs,
            stroke: style.stroke,
            background: style.background
        )
    }

    // MARK: - Private
    // `**` opens and closes emphasis. A last `**` that nothing closes is text.
    private func spans(
        of text: String,
        style: TextStyle
    ) -> [TextSpan] {
        var parts = text.components(separatedBy: "**")
        if parts.count % 2 == 0 {
            let last = parts.removeLast()
            parts[parts.count - 1] += "**" + last
        }

        return parts.enumerated().map { index, part in
            TextSpan(text: part, color: index % 2 == 1 ? style.emphasis : style.color)
        }
    }

    // `\n` ends a paragraph, whichever span it is in.
    private func paragraphs(of spans: [TextSpan]) -> [[TextSpan]] {
        spans.reduce(into: [[TextSpan]()]) { paragraphs, span in
            for (index, piece) in span.text.components(separatedBy: "\n").enumerated() {
                if index > 0 {
                    paragraphs.append([])
                }
                if !piece.isEmpty {
                    paragraphs[paragraphs.count - 1].append(TextSpan(text: piece, color: span.color))
                }
            }
        }
    }

    // Lines fill up to the width, broken only between words, and spaces at the end of a line hang outside it. A word
    // wider than the width starts a line of its own and breaks inside where UAX #14 allows, and a piece of it still
    // wider overflows alone. Without a width only a mandatory break ends a line.
    private func lines(
        of paragraph: [TextSpan],
        face: FontFace,
        size: Double,
        width: Double?
    ) throws -> [TextLine] {
        let scalars = paragraph.flatMap { Array($0.text.unicodeScalars) }
        let glyphs = try shaped(paragraph, face: face, size: size)
        let breaks = breaker.breaks(in: scalars)
        let starts = [0] + scalars.indices.filter { $0 > 0 && [.allowed, .mandatory].contains(breaks[$0]) }

        var lines: [[ColoredGlyph]] = []
        var current: [ColoredGlyph] = []
        for (index, start) in starts.enumerated() {
            let end = starts.indices.contains(index + 1) ? starts[index + 1] : scalars.count
            let word = glyphs.filter { (start..<end).contains($0.glyph.offset) }
            let isTooWide = width.map { visibleWidth(of: word, scalars: scalars) > $0 } ?? false
            if isTooWide && !current.isEmpty {
                lines.append(current)
                current = []
            }

            for piece in isTooWide ? pieces(of: word, breaks: breaks) : [word] {
                let candidate = current + piece
                let overflows = width.map { !current.isEmpty && visibleWidth(of: candidate, scalars: scalars) > $0 }

                if overflows ?? false {
                    lines.append(current)
                    current = piece
                } else {
                    current = candidate
                }
            }
            if end < scalars.count, breaks[end] == .mandatory {
                lines.append(current)
                current = []
            }
        }
        lines.append(current)

        return lines.map { glyphs in TextLine(glyphs: glyphs, width: visibleWidth(of: glyphs, scalars: scalars)) }
    }

    // A word's glyphs split where a break falls inside it. Glyphs of one scalar stay together.
    private func pieces(
        of word: [ColoredGlyph],
        breaks: [LineBreak]
    ) -> [[ColoredGlyph]] {
        word.reduce(into: [[ColoredGlyph]]()) { pieces, glyph in
            let offset = glyph.glyph.offset
            if pieces.last?.last.map({ $0.glyph.offset != offset && breaks[offset] == .insideWord }) ?? true {
                pieces.append([])
            }
            pieces[pieces.count - 1].append(glyph)
        }
    }

    // Each span is shaped on its own, since a colour change is a run boundary, and its glyphs are told by the scalar
    // they start at in the whole paragraph.
    private func shaped(
        _ paragraph: [TextSpan],
        face: FontFace,
        size: Double
    ) throws -> [ColoredGlyph] {
        var start = 0
        var glyphs: [ColoredGlyph] = []
        for span in paragraph {
            for run in try shaper.shape(span.text, face: face, size: size) {
                glyphs += run.glyphs.map { glyph in
                    ColoredGlyph(
                        glyph: ShapedGlyph(id: glyph.id, advance: glyph.advance, offset: glyph.offset + start),
                        face: run.face,
                        color: span.color
                    )
                }
            }
            start += span.text.unicodeScalars.count
        }

        return glyphs
    }

    private func visibleWidth(
        of glyphs: [ColoredGlyph],
        scalars: [Unicode.Scalar]
    ) -> Double {
        let hanging = glyphs.reversed().prefix { scalars[$0.glyph.offset].properties.isWhitespace }.count
        return glyphs.dropLast(hanging).map(\.glyph.advance).reduce(0, +)
    }

    private func alignmentOffset(
        of line: TextLine,
        in width: Double,
        align: TextAlignment
    ) -> Double {
        switch align {
        case .left:
            0

        case .center:
            (width - line.width) / 2

        case .right:
            width - line.width
        }
    }

    // Each line takes the line height, with the face's extent centred in it.
    private func baseline(
        of index: Int,
        face: FontFace,
        style: TextStyle
    ) -> Double {
        let extent = (face.ascent + face.descent) * style.size
        return Double(index) * style.lineHeight + (style.lineHeight - extent) / 2 + face.ascent * style.size
    }

    // Glyphs of one line in one face and colour make one run.
    private func placed(
        _ line: TextLine,
        origin: Point,
        size: Double
    ) -> [GlyphRun] {
        var runs: [GlyphRun] = []
        var x = origin.x
        for glyph in line.glyphs {
            let positioned = PositionedGlyph(id: glyph.glyph.id, x: x, y: origin.y)
            x += glyph.glyph.advance

            if let last = runs.last, last.face == glyph.face, last.color == glyph.color {
                runs[runs.count - 1] = GlyphRun(
                    face: last.face,
                    size: size,
                    color: last.color,
                    glyphs: last.glyphs + [positioned]
                )
            } else {
                runs.append(GlyphRun(face: glyph.face, size: size, color: glyph.color, glyphs: [positioned]))
            }
        }

        return runs
    }
}
