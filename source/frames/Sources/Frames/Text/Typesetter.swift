//
//  Typesetter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Each run is shaped on its own, and lines break by UAX #14 over the text of all runs together. Tracking is added after
// every grapheme cluster but the last on its line, so it widens no line past its last character and moves no centred
// or right-aligned line off its place.
struct Typesetter: Sendable {
    // MARK: - Property
    private let shaper: any ShapingProvider
    private let breaker = LineBreaker()
    private let finder = UnitFinder()

    // MARK: - Initializer
    init(shaper: any ShapingProvider) {
        self.shaper = shaper
    }

    // MARK: - Public
    // `width` is the width of the text box in output pixels, and the text wraps at it with each run at its widest
    // tracking, while glyphs are placed at its static tracking. Without it the text breaks only at `\n` and the box
    // is as wide as the widest line. A piece of a word wider than `width` that cannot break widens the box to hold it.
    // Text that takes more lines than its paragraph style's `lines`, counting every `\n`, stops. A style of one line
    // wraps at no width, and is too wide when it is wider than `width`. Lines lie the line height apart, baseline to
    // baseline: the first baseline is its line's largest ascent below the top, and the box ends the last line's largest
    // descent below the last. `unit` splits the text into units, for a title animated by unit.
    func layout(
        _ runs: [TextRun],
        paragraph style: ParagraphStyle,
        width: Double?,
        unit: TextUnit? = nil,
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
        var placedRuns: [GlyphRun] = []
        var placedLines: [PlacedLine] = []
        var placedClusters: [[PlacedCluster]] = []
        var extents: [ClosedRange<Double>] = []
        for (index, line) in lines.enumerated() {
            let origin = Point(
                x: padding.width + style.align.offset(of: line.width, in: textWidth),
                y: firstBaseline + Double(index) * style.lineHeight
            )
            let (runs, clusters) = placed(line, origin: origin, firstRun: placedRuns.count)
            placedRuns += runs
            placedLines.append(PlacedLine(width: line.width, baseline: origin.y, clusters: clusters.map(\.glyphs)))
            placedClusters.append(clusters)
            extents.append((origin.y - line.ascent)...(origin.y + line.descent))
        }
        let textHeight = Double(max(lines.count - 1, 0)) * style.lineHeight
            + (lines.first?.ascent ?? 0)
            + (lines.last?.descent ?? 0)

        return TextLayout(
            size: Size(width: textWidth + padding.width * 2, height: textHeight + padding.height * 2),
            textBox: Rectangle(x: padding.width, y: padding.height, width: textWidth, height: textHeight),
            width: width,
            lines: placedLines,
            runs: placedRuns,
            units: unit.map { finder.units(by: $0, lines: placedClusters, extents: extents, runs: placedRuns) },
            background: style.background,
            align: style.align,
            lineHeight: style.lineHeight
        )
    }

    // MARK: - Private
    // `\n` ends a paragraph, whichever run it is in. Each paragraph begins with a piece of the run its first scalar or
    // the `\n` before it lies in, empty or not, so a line with no glyphs takes that run's extent. Each piece keeps
    // the index of its run.
    private func paragraphs(of runs: [TextRun]) -> [[(source: Int, run: TextRun)]] {
        runs.enumerated().reduce(into: [[(source: Int, run: TextRun)]]()) { paragraphs, element in
            let (source, run) = element
            for (index, piece) in run.text.components(separatedBy: "\n").enumerated() {
                let text = TextRun(
                    text: piece,
                    style: run.style,
                    faces: run.faces,
                    widestTracking: run.widestTracking,
                    isSpacedApart: run.isSpacedApart
                )
                if index > 0 || paragraphs.isEmpty {
                    paragraphs.append([(source, text)])
                } else if !piece.isEmpty {
                    paragraphs[paragraphs.count - 1].append((source, text))
                }
            }
        }
    }

    // Lines fill up to the width, broken only between words, and spaces at the end of a line hang outside it. A word
    // wider than the width starts a line of its own and breaks inside where UAX #14 allows, and a piece of it still
    // wider overflows alone. Without a width only a mandatory break ends a line.
    private func lines(
        of paragraph: [(source: Int, run: TextRun)],
        width: Double?,
        place: Place,
        kind: String
    ) throws -> [TextLine] {
        let scalars = paragraph.flatMap { Array($0.run.text.unicodeScalars) }
        let glyphs = try shaped(paragraph, place: place, kind: kind)
        let breaks = breaker.breaks(in: scalars)
        let starts = [0] + scalars.indices.filter { $0 > 0 && [.allowed, .mandatory].contains(breaks[$0]) }

        var lines: [[StyledGlyph]] = []
        var current: [StyledGlyph] = []
        for (index, start) in starts.enumerated() {
            let end = starts.indices.contains(index + 1) ? starts[index + 1] : scalars.count
            let word = glyphs.filter { (start..<end).contains($0.glyph.offset) }
            let isTooWide = width.map { breakWidth(of: word) > $0 } ?? false
            if isTooWide && !current.isEmpty {
                lines.append(current)
                current = []
            }

            for piece in isTooWide ? pieces(of: word, breaks: breaks) : [word] {
                let candidate = current + piece
                let overflows = width.map { !current.isEmpty && breakWidth(of: candidate) > $0 }

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
        let home = paragraph.first.map { [TextExtent(face: $0.run.faces[0], size: $0.run.style.size)] } ?? []
        return lines.map { glyphs in
            let extents = glyphs.isEmpty ? home : glyphs.map { TextExtent(face: $0.face, size: $0.style.size) }
            return TextLine(
                glyphs: glyphs,
                width: visibleWidth(of: glyphs, tracking: \.tracking),
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
        _ paragraph: [(source: Int, run: TextRun)],
        place: Place,
        kind: String
    ) throws -> [StyledGlyph] {
        var start = 0
        var glyphs: [StyledGlyph] = []
        for (source, run) in paragraph {
            let shapedRuns = try Result { try shape(run) }
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
            let runGlyphs = shapedRuns.flatMap { shaped in shaped.glyphs.map { (face: shaped.face, glyph: $0) } }
            let clusters = clusters(of: run.text, glyphOffsets: runGlyphs.map(\.glyph.offset))
            let scalars = Array(run.text.unicodeScalars)
            let em = run.style.size / 1000

            glyphs += zip(runGlyphs, clusters).map { element, clusters in
                let (face, glyph) = element
                return StyledGlyph(
                    glyph: ShapedGlyph(id: glyph.id, advance: glyph.advance, offset: glyph.offset + start),
                    isSpace: scalars[glyph.offset].properties.isWhitespace,
                    face: face,
                    source: source,
                    style: run.style,
                    runFace: run.faces[0],
                    clusters: clusters,
                    tracking: Double(clusters.count) * run.style.tracking * em,
                    widestTracking: Double(clusters.count) * run.widestTracking * em
                )
            }
            start += run.text.unicodeScalars.count
        }

        return glyphs
    }

    // The grapheme clusters that end in each glyph: a cluster ends in the last glyph that starts at or before its last
    // scalar, so a ligature over two clusters takes the tracking of both.
    private func clusters(
        of text: String,
        glyphOffsets: [Int]
    ) -> [[Character]] {
        var clusters = Array(repeating: [Character](), count: glyphOffsets.count)
        var end = 0
        for character in text {
            end += character.unicodeScalars.count
            if let index = glyphOffsets.lastIndex(where: { $0 <= end - 1 }) {
                clusters[index].append(character)
            }
        }

        return clusters
    }

    // The style's features over `kern`, which `kerning` sets, and over the optional ligatures, off in a run spaced
    // apart. A later setting of a tag replaces an earlier one.
    private func shape(_ run: TextRun) throws -> [ShapedRun] {
        let style = run.style
        let ligatures = run.isSpacedApart ? ["liga", "clig", "dlig"].map { FontFeature(tag: $0, value: 0) } : []
        let settings = [FontFeature(tag: "kern", value: style.isKerned ? 1 : 0)] + ligatures + style.features
        let features = settings.reduce(into: [FontFeature]()) { features, feature in
            features.removeAll { $0.tag == feature.tag }
            features.append(feature)
        }

        return try shaper.shape(
            run.text,
            faces: run.faces,
            size: style.size,
            features: features,
            weight: style.weight,
            italic: style.italic
        )
    }

    // The glyphs that end a line on spaces hang outside it.
    private func visibleGlyphs(of glyphs: [StyledGlyph]) -> ArraySlice<StyledGlyph> {
        let hanging = glyphs.reversed().prefix(while: \.isSpace).count

        return glyphs.dropLast(hanging)
    }

    // The advances and the tracking between the visible glyphs, without the tracking after the last.
    private func visibleWidth(
        of glyphs: [StyledGlyph],
        tracking: KeyPath<StyledGlyph, Double>
    ) -> Double {
        let visible = visibleGlyphs(of: glyphs)
        let width = visible.map { $0.glyph.advance + $0[keyPath: tracking] }.reduce(0, +)

        return width - (visible.last?[keyPath: tracking] ?? 0)
    }

    private func breakWidth(of glyphs: [StyledGlyph]) -> Double {
        visibleWidth(of: glyphs, tracking: \.widestTracking)
    }

    // Glyphs of one line of one text run in one face make one glyph run, and the runs of a line share its baseline.
    // The pieces of a text run's highlight and underline span its glyphs on the line, from the origin of the first to
    // the end of the advance of the last, the spaces that end the line excluded. The line's clusters name glyphs by
    // the index of their run among the text's, the first of this line's runs being `firstRun`.
    private func placed(
        _ line: TextLine,
        origin: Point,
        firstRun: Int
    ) -> (runs: [GlyphRun], clusters: [PlacedCluster]) {
        var runs: [GlyphRun] = []
        var clusters: [PlacedCluster] = []
        var cluster: (run: Int, first: Int, count: Int, start: Double)?
        var x = origin.x
        var spans: [(source: Int, run: Int, from: Double, to: Double)] = []
        let visibleCount = visibleGlyphs(of: line.glyphs).count
        for (index, glyph) in line.glyphs.enumerated() {
            let positioned = PositionedGlyph(id: glyph.glyph.id, x: x, y: origin.y)
            let end = x + glyph.glyph.advance
            x = end + glyph.tracking

            let isSameRun = runs.last.map { $0.source == glyph.source && $0.face == glyph.face } ?? false
            if let last = runs.last, isSameRun {
                runs[runs.count - 1] = GlyphRun(
                    source: last.source,
                    face: last.face,
                    size: last.size,
                    glyphs: last.glyphs + [positioned]
                )
            } else {
                runs.append(GlyphRun(
                    source: glyph.source,
                    face: glyph.face,
                    size: glyph.style.size,
                    glyphs: [positioned]
                ))
            }

            guard index < visibleCount else { continue }
            // A cluster split over two faces is cut where its face changes: its glyphs in the earlier face are in no
            // cluster and stay where they were set.
            let run = firstRun + runs.count - 1
            let first = runs[runs.count - 1].glyphs.count - 1
            let start = cluster.flatMap { $0.run == run ? $0 : nil }
                ?? (run: run, first: first, count: 0, start: positioned.x)
            cluster = (run: run, first: start.first, count: start.count + 1, start: start.start)
            if let character = glyph.clusters.first {
                clusters.append(PlacedCluster(
                    glyphs: GlyphRange(run: run, first: start.first, count: start.count + 1),
                    character: character,
                    start: start.start,
                    end: end
                ))
                clusters += glyph.clusters.dropFirst().map { character in
                    PlacedCluster(
                        glyphs: GlyphRange(run: run, first: first + 1, count: 0),
                        character: character,
                        start: positioned.x,
                        end: end
                    )
                }
                cluster = nil
            }

            if let last = spans.last, last.source == glyph.source {
                spans[spans.count - 1].to = end
            } else {
                spans.append((glyph.source, runs.count - 1, positioned.x, end))
            }
        }

        for span in spans {
            let run = runs[span.run]
            let glyph = line.glyphs.first { $0.source == span.source }
            guard let style = glyph?.style, let face = glyph?.runFace else { continue }
            let extent = TextExtent(face: face, size: style.size)
            let highlight = Rectangle(
                x: span.from,
                y: origin.y - extent.ascent,
                width: span.to - span.from,
                height: extent.ascent + extent.descent
            )
            let underline = UnderlinePiece(x: span.from, y: origin.y, width: span.to - span.from)
            runs[span.run] = GlyphRun(
                source: run.source,
                face: run.face,
                size: run.size,
                glyphs: run.glyphs,
                highlights: style.isHighlighted ? [highlight] : [],
                underlines: style.isUnderlined ? [underline] : []
            )
        }

        return (runs, clusters)
    }
}
