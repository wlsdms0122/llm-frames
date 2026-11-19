//
//  Typesetter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Each run is shaped on its own, and lines break by UAX #14 over the text of all runs together.
struct Typesetter: Sendable {
    // MARK: - Property
    private let shaper: any ShapingProvider
    private let breaker = LineBreaker()

    // MARK: - Initializer
    init(shaper: any ShapingProvider) {
        self.shaper = shaper
    }

    // MARK: - Public
    // `width` is the width of the text box in output pixels, and the text wraps at it. Without it the text breaks
    // only at `\n` and the box is as wide as the widest line. A piece of a word wider than `width` that cannot break
    // widens the box to hold it. Text that takes more lines than its paragraph style's `lines`, counting every `\n`,
    // stops. A style of one line wraps at no width, and is too wide when it is wider than `width`. Lines lie the line
    // height apart, baseline to baseline: the first baseline is its line's largest ascent below the top, and the box
    // ends the last line's largest descent below the last.
    func layout(
        _ runs: [TextRun],
        paragraph style: ParagraphStyle,
        width: Double?,
        place: Place,
        kind: String
    ) throws -> TextLayout {
        let isOneLine = style.lines == 1
        let lines = try paragraphs(of: runs).flatMap { paragraph in
            try self.lines(of: paragraph, width: isOneLine ? nil : width, place: place, kind: kind)
        }
        if let limit = style.lines, lines.count > limit {
            throw TextError.tooManyLines(place: place, kind: kind, count: lines.count, limit: limit)
        }

        let widest = lines.map(\.width).reduce(0, max)
        if isOneLine, let width, widest > width {
            throw TextError.tooWide(place: place, kind: kind, width: widest, room: width)
        }
        let textWidth = max(width ?? 0, widest)

        let padding = style.background?.padding ?? Size(width: 0, height: 0)
        let firstBaseline = padding.height + (lines.first?.ascent ?? 0)
        let placedRuns = lines.enumerated().flatMap { index, line in
            placed(
                line,
                origin: Point(
                    x: padding.width + alignmentOffset(of: line, in: textWidth, align: style.align),
                    y: firstBaseline + Double(index) * style.lineHeight
                )
            )
        }
        let textHeight = Double(max(lines.count - 1, 0)) * style.lineHeight
            + (lines.first?.ascent ?? 0)
            + (lines.last?.descent ?? 0)

        return TextLayout(
            size: Size(width: textWidth + padding.width * 2, height: textHeight + padding.height * 2),
            lineCount: lines.count,
            runs: placedRuns,
            background: style.background
        )
    }

    // MARK: - Private
    // `\n` ends a paragraph, whichever run it is in. Each paragraph begins with a piece of the run its first scalar or
    // the `\n` before it lies in, empty or not, so a line with no glyphs takes that run's extent.
    private func paragraphs(of runs: [TextRun]) -> [[TextRun]] {
        runs.reduce(into: [[TextRun]]()) { paragraphs, run in
            for (index, piece) in run.text.components(separatedBy: "\n").enumerated() {
                let text = TextRun(text: piece, style: run.style, face: run.face)
                if index > 0 || paragraphs.isEmpty {
                    paragraphs.append([text])
                } else if !piece.isEmpty {
                    paragraphs[paragraphs.count - 1].append(text)
                }
            }
        }
    }

    // Lines fill up to the width, broken only between words, and spaces at the end of a line hang outside it. A word
    // wider than the width starts a line of its own and breaks inside where UAX #14 allows, and a piece of it still
    // wider overflows alone. Without a width only a mandatory break ends a line.
    private func lines(
        of paragraph: [TextRun],
        width: Double?,
        place: Place,
        kind: String
    ) throws -> [TextLine] {
        let scalars = paragraph.flatMap { Array($0.text.unicodeScalars) }
        let glyphs = try shaped(paragraph, place: place, kind: kind)
        let breaks = breaker.breaks(in: scalars)
        let starts = [0] + scalars.indices.filter { $0 > 0 && [.allowed, .mandatory].contains(breaks[$0]) }

        var lines: [[StyledGlyph]] = []
        var current: [StyledGlyph] = []
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

        // A line with no glyphs is a paragraph with no text, and takes the extent of the run it begins in.
        let home = paragraph.first.map { [TextExtent(face: $0.face, size: $0.style.size)] } ?? []
        return lines.map { glyphs in
            let extents = glyphs.isEmpty ? home : glyphs.map { TextExtent(face: $0.face, size: $0.style.size) }
            return TextLine(
                glyphs: glyphs,
                width: visibleWidth(of: glyphs, scalars: scalars),
                ascent: extents.map(\.ascent).reduce(0, max),
                descent: extents.map(\.descent).reduce(0, max)
            )
        }
    }

    // A word's glyphs split where a break falls inside it. Glyphs of one scalar stay together.
    private func pieces(
        of word: [StyledGlyph],
        breaks: [LineBreak]
    ) -> [[StyledGlyph]] {
        word.reduce(into: [[StyledGlyph]]()) { pieces, glyph in
            let offset = glyph.glyph.offset
            if pieces.last?.last.map({ $0.glyph.offset != offset && breaks[offset] == .insideWord }) ?? true {
                pieces.append([])
            }
            pieces[pieces.count - 1].append(glyph)
        }
    }

    // Each run is shaped on its own, since a run boundary ends a shaping run, and its glyphs are told by the scalar
    // they start at in the whole paragraph.
    private func shaped(
        _ paragraph: [TextRun],
        place: Place,
        kind: String
    ) throws -> [StyledGlyph] {
        var start = 0
        var glyphs: [StyledGlyph] = []
        for run in paragraph {
            let shapedRuns = try Result { try shaper.shape(run.text, face: run.face, size: run.style.size) }
                .mapError { error in
                    ProviderError.failed(
                        provider: .shaping,
                        place: place,
                        kind: kind,
                        picture: nil,
                        message: "\(error)"
                    )
                }
                .get()
            
            for shaped in shapedRuns {
                glyphs += shaped.glyphs.map { glyph in
                    StyledGlyph(
                        glyph: ShapedGlyph(id: glyph.id, advance: glyph.advance, offset: glyph.offset + start),
                        face: shaped.face,
                        style: run.style
                    )
                }
            }
            start += run.text.unicodeScalars.count
        }

        return glyphs
    }

    private func visibleWidth(
        of glyphs: [StyledGlyph],
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

    // Glyphs of one line in one face, size, colour and stroke make one run, and the runs of a line share its baseline.
    private func placed(
        _ line: TextLine,
        origin: Point
    ) -> [GlyphRun] {
        var runs: [GlyphRun] = []
        var x = origin.x
        for glyph in line.glyphs {
            let positioned = PositionedGlyph(id: glyph.glyph.id, x: x, y: origin.y)
            x += glyph.glyph.advance

            let style = glyph.style
            let isSameLook = runs.last.map { last in
                last.face == glyph.face && last.size == style.size && last.color == style.color
                    && last.stroke == style.stroke
            } ?? false
            if let last = runs.last, isSameLook {
                runs[runs.count - 1] = GlyphRun(
                    face: last.face,
                    size: last.size,
                    color: last.color,
                    stroke: last.stroke,
                    glyphs: last.glyphs + [positioned]
                )
            } else {
                runs.append(GlyphRun(
                    face: glyph.face,
                    size: style.size,
                    color: style.color,
                    stroke: style.stroke,
                    glyphs: [positioned]
                ))
            }
        }

        return runs
    }
}
