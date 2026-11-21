//
//  Typesetter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Each run is shaped on its own, and lines break by UAX #14 over the text of all runs together. A line's glyphs are cut
// into groups by the characters they are set from, and a group's glyphs belong to its first character. Tracking is
// added after every character with glyphs of its own but the last on its line, so it widens no line past its last
// character and moves no centred or right-aligned line off its place.
struct Typesetter: Sendable {
    // MARK: - Property
    private let shaper: any ShapingProvider
    private let breaker = LineBreaker()
    private let segmenter = WordSegmenter()
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
        let runs = clustered(runs)
        let isOneLine = style.lines == 1
        let lines = try paragraphs(of: runs).flatMap { paragraph in
            try self.lines(
                of: paragraph.pieces,
                from: paragraph.start,
                width: isOneLine ? nil : width,
                place: place,
                kind: kind
            )
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
        var spans: [[ClosedRange<Double>]] = []
        for (index, line) in lines.enumerated() {
            let origin = Point(
                x: padding.width + style.align.offset(of: line.width, in: textWidth),
                y: firstBaseline + Double(index) * style.lineHeight
            )
            let placed = placed(line, index: index, origin: origin, firstRun: placedRuns.count)
            placedRuns += placed.runs
            placedLines.append(placed.line)
            spans.append(placed.spans)
        }
        let textHeight = Double(max(lines.count - 1, 0)) * style.lineHeight
            + (lines.first?.ascent ?? 0)
            + (lines.last?.descent ?? 0)

        let text = runs.map(\.text).joined()
        let words = text.scalarRanges(of: segmenter.words(of: Array(text)))

        return TextLayout(
            text: text,
            words: words,
            size: Size(width: textWidth + padding.width * 2, height: textHeight + padding.height * 2),
            textBox: Rectangle(x: padding.width, y: padding.height, width: textWidth, height: textHeight),
            width: width,
            lines: placedLines,
            runs: placedRuns,
            units: unit.map { unit in
                finder.units(by: unit, text: text, words: words, lines: placedLines, spans: spans, runs: placedRuns)
            },
            background: style.background,
            align: style.align,
            lineHeight: style.lineHeight
        )
    }

    // MARK: - Private
    // A grapheme cluster a run boundary falls inside is set with the run its first scalar is in, so each boundary moves
    // to the end of the cluster it falls inside. The text of all runs together stays as it is.
    private func clustered(_ runs: [TextRun]) -> [TextRun] {
        let text = runs.map(\.text).joined()
        let scalars = Array(text.unicodeScalars)
        let ends = text.reduce(into: [0]) { ends, character in
            ends.append(ends[ends.count - 1] + character.unicodeScalars.count)
        }
        var starts: [Int] = []
        var offset = 0
        for run in runs {
            starts.append(ends.first { $0 >= offset } ?? scalars.count)
            offset += run.text.unicodeScalars.count
        }

        return runs.enumerated().map { index, run in
            let end = starts.indices.contains(index + 1) ? starts[index + 1] : scalars.count
            var piece = String.UnicodeScalarView()
            piece.append(contentsOf: scalars[starts[index]..<end])

            return TextRun(
                text: String(piece),
                style: run.style,
                faces: run.faces,
                widestTracking: run.widestTracking,
                isSpacedApart: run.isSpacedApart
            )
        }
    }

    // `\n` ends a paragraph, whichever run it is in. Each paragraph begins with a piece of the run its first scalar or
    // the `\n` before it lies in, empty or not, so a line with no glyphs takes that run's extent. Each piece keeps
    // the index of its run, and each paragraph the index of its first scalar in the text of all runs.
    private func paragraphs(of runs: [TextRun]) -> [(start: Int, pieces: [(source: Int, run: TextRun)])] {
        var paragraphs: [(start: Int, pieces: [(source: Int, run: TextRun)])] = []
        var offset = 0
        for (source, run) in runs.enumerated() {
            for (index, piece) in run.text.components(separatedBy: "\n").enumerated() {
                let text = TextRun(
                    text: piece,
                    style: run.style,
                    faces: run.faces,
                    widestTracking: run.widestTracking,
                    isSpacedApart: run.isSpacedApart
                )
                offset += index > 0 ? 1 : 0
                if index > 0 || paragraphs.isEmpty {
                    paragraphs.append((offset, [(source, text)]))
                } else if !piece.isEmpty {
                    paragraphs[paragraphs.count - 1].pieces.append((source, text))
                }
                offset += piece.unicodeScalars.count
            }
        }

        return paragraphs
    }

    // Lines fill up to the width, broken only between words, and spaces at the end of a line hang outside it. A word
    // wider than the width starts a line of its own and breaks inside where UAX #14 allows, and a piece of it still
    // wider overflows alone. Without a width only a mandatory break ends a line. A line breaks only before a character
    // with glyphs of its own, so a group of glyphs stays on one line. `start` is the index of the paragraph's first
    // scalar in the text of all runs.
    private func lines(
        of paragraph: [(source: Int, run: TextRun)],
        from start: Int,
        width: Double?,
        place: Place,
        kind: String
    ) throws -> [TextLine] {
        let scalars = paragraph.flatMap { Array($0.run.text.unicodeScalars) }
        let characters = try shaped(paragraph, from: start, place: place, kind: kind)
        let breaks = breaker.breaks(in: scalars)
        let starts = [0] + characters.compactMap { character -> Int? in
            let offset = character.range.lowerBound - start
            let isBreak = [.allowed, .mandatory].contains(breaks[offset])

            return offset > 0 && !character.glyphs.isEmpty && isBreak ? offset : nil
        }

        var lines: [[StyledCharacter]] = []
        var current: [StyledCharacter] = []
        for (index, wordStart) in starts.enumerated() {
            let end = starts.indices.contains(index + 1) ? starts[index + 1] : scalars.count
            let word = characters.filter { (wordStart..<end).contains($0.range.lowerBound - start) }
            let isTooWide = width.map { breakWidth(of: word) > $0 } ?? false
            if isTooWide && !current.isEmpty {
                lines.append(current)
                current = []
            }

            for piece in isTooWide ? pieces(of: word, from: start, breaks: breaks) : [word] {
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

        // A line with no glyphs, as a paragraph with no text is, takes the extent of the run its paragraph begins in.
        let home = paragraph.first.map { [TextExtent(face: $0.run.faces[0], size: $0.run.style.size)] } ?? []
        return lines.map { characters in
            let glyphs = characters.flatMap(\.glyphs)
            let extents = glyphs.isEmpty ? home : glyphs.map { TextExtent(face: $0.face, size: $0.style.size) }
            let visible = visibleCharacters(of: characters)
            let first = visible.first?.range.lowerBound ?? characters.first?.range.lowerBound ?? start

            return TextLine(
                characters: characters,
                range: first..<(visible.last?.range.upperBound ?? first),
                width: visibleWidth(of: characters, tracking: \.tracking),
                ascent: extents.map(\.ascent).reduce(0, max),
                descent: extents.map(\.descent).reduce(0, max)
            )
        }
    }

    // A word's characters split before each character with glyphs of its own where a break falls inside the word.
    private func pieces(
        of word: [StyledCharacter],
        from start: Int,
        breaks: [LineBreak]
    ) -> [[StyledCharacter]] {
        word.reduce(into: [[StyledCharacter]]()) { pieces, character in
            let isBreak = !character.glyphs.isEmpty && breaks[character.range.lowerBound - start] == .insideWord
            if pieces.isEmpty || isBreak {
                pieces.append([])
            }
            pieces[pieces.count - 1].append(character)
        }
    }

    // Each run is shaped on its own, since a run boundary ends a shaping run, and its glyphs are told by the scalar
    // they start at in the whole paragraph. Each character is a grapheme cluster of its run, its range counted from
    // `start`, and owns the glyphs of the group it is the first character of.
    private func shaped(
        _ paragraph: [(source: Int, run: TextRun)],
        from start: Int,
        place: Place,
        kind: String
    ) throws -> [StyledCharacter] {
        var offset = 0
        var glyphs: [StyledGlyph] = []
        var characters: [(character: Character, range: Range<Int>, source: Int, run: TextRun)] = []
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
            let runStart = offset
            glyphs += shapedRuns.flatMap { shaped in
                shaped.glyphs.map { glyph in
                    StyledGlyph(
                        glyph: ShapedGlyph(
                            id: glyph.id,
                            advance: glyph.advance,
                            offset: glyph.offset + runStart,
                            placementOffset: glyph.placementOffset
                        ),
                        face: shaped.face,
                        source: source,
                        style: run.style,
                        runFace: run.faces[0]
                    )
                }
            }
            for character in run.text {
                let count = character.unicodeScalars.count
                characters.append((character, offset..<(offset + count), source, run))
                offset += count
            }
        }

        let owned = owners(ofGlyphsAt: glyphs.map(\.glyph.offset), in: characters.map(\.range))
        return zip(characters, owned).map { element, indices in
            let (character, range, source, run) = element
            let em = run.style.size / 1000
            let isOwner = !indices.isEmpty

            return StyledCharacter(
                character: character,
                range: (range.lowerBound + start)..<(range.upperBound + start),
                source: source,
                style: run.style,
                runFace: run.faces[0],
                glyphs: indices.map { glyphs[$0] },
                isSpace: character.unicodeScalars.first?.properties.isWhitespace ?? false,
                tracking: isOwner ? run.style.tracking * em : 0,
                widestTracking: isOwner ? run.widestTracking * em : 0
            )
        }
    }

    // The glyphs each character owns, by index. Each glyph is taken with the character its scalar is in, the glyphs
    // are cut into groups where that character changes, and neighbouring groups merge until every character of a
    // group comes before every character of the next. A group's glyphs belong to its first character, the first
    // group's to the first character of all, and the characters after it up to the next group's first own none.
    private func owners(
        ofGlyphsAt offsets: [Int],
        in ranges: [Range<Int>]
    ) -> [[Int]] {
        let characterAt = ranges.enumerated().flatMap { index, range in Array(repeating: index, count: range.count) }
        var groups: [(glyphs: [Int], first: Int, last: Int)] = []
        var previous: Int?
        for (glyph, offset) in offsets.enumerated() {
            let character = characterAt[offset]
            defer { previous = character }
            guard previous != character else {
                groups[groups.count - 1].glyphs.append(glyph)
                continue
            }

            groups.append(([glyph], character, character))
            while groups.count > 1, groups[groups.count - 2].last >= groups[groups.count - 1].first {
                let later = groups.removeLast()
                let earlier = groups.removeLast()
                groups.append((
                    glyphs: earlier.glyphs + later.glyphs,
                    first: min(earlier.first, later.first),
                    last: max(earlier.last, later.last)
                ))
            }
        }

        var owned = ranges.map { _ in [Int]() }
        for (index, group) in groups.enumerated() {
            owned[index == 0 ? 0 : group.first] = group.glyphs
        }

        return owned
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

    // A line's characters before the spaces that end it, which hang outside it.
    private func visibleCharacters(of characters: [StyledCharacter]) -> ArraySlice<StyledCharacter> {
        characters.dropLast(characters.reversed().prefix(while: \.isSpace).count)
    }

    // The advances of the visible characters and the tracking after each of them with glyphs of its own but the last.
    private func visibleWidth(
        of characters: [StyledCharacter],
        tracking: KeyPath<StyledCharacter, Double>
    ) -> Double {
        let visible = visibleCharacters(of: characters)
        let tracked = visible.filter { !$0.glyphs.isEmpty }.dropLast()

        return visible.map(\.advance).reduce(0, +) + tracked.map { $0[keyPath: tracking] }.reduce(0, +)
    }

    private func breakWidth(of characters: [StyledCharacter]) -> Double {
        visibleWidth(of: characters, tracking: \.widestTracking)
    }

    // Glyphs of one line of one text run in one face make one glyph run, and the runs of a line share its baseline.
    // Each glyph lies at the pen with its placement offset, and the pen moves by advances and by the tracking after
    // each character with glyphs of its own but the line's last, so the spaces that hang past the line's end follow its
    // last character untracked. A character with no glyph of its own is a range of count 0 after its group's glyphs and
    // spans its group's first character, and on a line with no glyph it is a range of count 0 at glyph 0 of the line's
    // first run, written for it with no glyphs, spanning nothing at the line's start. The pieces of a text run's
    // highlight and underline span its characters on the line, from the start of the first one's span to the end of the
    // last one's, the spaces that end the line excluded. A character's span is its glyph box across the line, from the
    // pen where its glyphs begin, as wide as their advances, and the spans of the line's characters are given in order.
    // The line's clusters name glyphs by the index of their run among the text's, the first of this line's runs being
    // `firstRun`. `index` is the line's among the text's.
    private func placed(
        _ line: TextLine,
        index lineIndex: Int,
        origin: Point,
        firstRun: Int
    ) -> (
        runs: [GlyphRun],
        line: PlacedLine,
        spans: [ClosedRange<Double>]
    ) {
        var runs: [GlyphRun] = []
        var placed: [(cluster: PlacedCluster, character: StyledCharacter, span: ClosedRange<Double>)] = []
        var group: (glyphs: GlyphRange, span: ClosedRange<Double>)?
        var x = origin.x
        let visibleCount = visibleCharacters(of: line.characters).count
        let last = line.characters.prefix(visibleCount).lastIndex { !$0.glyphs.isEmpty }
        for (index, character) in line.characters.enumerated() {
            guard !character.glyphs.isEmpty else {
                if group == nil && runs.isEmpty {
                    runs.append(GlyphRun(
                        source: character.source,
                        line: lineIndex,
                        face: character.runFace,
                        size: character.style.size,
                        glyphs: [],
                        staticTracking: character.style.tracking * character.style.size / 1000
                    ))
                }
                let end = GlyphRange(run: firstRun + runs.count - 1, first: runs[runs.count - 1].glyphs.count, count: 0)
                let held = group ?? (glyphs: end, span: x...x)
                let glyphs = GlyphRange(run: held.glyphs.run, first: held.glyphs.first + held.glyphs.count, count: 0)
                placed.append((PlacedCluster(glyphs: glyphs, range: character.range, advance: 0), character, held.span))
                continue
            }

            let start = x
            for glyph in character.glyphs {
                let positioned = PositionedGlyph(
                    id: glyph.glyph.id,
                    x: x,
                    y: origin.y,
                    placementOffset: glyph.glyph.placementOffset
                )
                x += glyph.glyph.advance

                if let previous = runs.last, previous.source == glyph.source, previous.face == glyph.face {
                    runs[runs.count - 1] = GlyphRun(
                        source: previous.source,
                        line: lineIndex,
                        face: previous.face,
                        size: previous.size,
                        glyphs: previous.glyphs + [positioned],
                        staticTracking: previous.staticTracking
                    )
                } else {
                    runs.append(GlyphRun(
                        source: glyph.source,
                        line: lineIndex,
                        face: glyph.face,
                        size: glyph.style.size,
                        glyphs: [positioned],
                        staticTracking: glyph.style.tracking * glyph.style.size / 1000
                    ))
                }
            }

            let count = character.glyphs.count
            let first = runs[runs.count - 1].glyphs.count - count
            let glyphs = GlyphRange(run: firstRun + runs.count - 1, first: first, count: count)
            let cluster = PlacedCluster(glyphs: glyphs, range: character.range, advance: character.advance)
            group = (glyphs, start...x)
            placed.append((cluster, character, start...x))
            if index < visibleCount && index != last {
                x += character.tracking
            }
        }

        var spans: [(source: Int, style: CharacterStyle, face: FontFace, from: Double, to: Double)] = []
        for (_, character, span) in placed.prefix(visibleCount) {
            if let previous = spans.last, previous.source == character.source {
                spans[spans.count - 1].to = span.upperBound
            } else {
                spans.append((character.source, character.style, character.runFace, span.lowerBound, span.upperBound))
            }
        }
        for span in spans {
            guard let holder = runs.firstIndex(where: { $0.source == span.source }) else { continue }

            let run = runs[holder]
            let extent = TextExtent(face: span.face, size: span.style.size)
            let highlight = Rectangle(
                x: span.from,
                y: origin.y - extent.ascent,
                width: span.to - span.from,
                height: extent.ascent + extent.descent
            )
            let underline = UnderlinePiece(x: span.from, y: origin.y, width: span.to - span.from)
            runs[holder] = GlyphRun(
                source: run.source,
                line: run.line,
                face: run.face,
                size: run.size,
                glyphs: run.glyphs,
                staticTracking: run.staticTracking,
                highlights: span.style.isHighlighted ? [highlight] : [],
                underlines: span.style.isUnderlined ? [underline] : []
            )
        }

        let characters = placed.prefix(visibleCount)
        return (
            runs,
            PlacedLine(
                width: line.width,
                baseline: origin.y,
                ascent: line.ascent,
                descent: line.descent,
                range: line.range,
                clusters: characters.map(\.cluster),
                hanging: placed.dropFirst(visibleCount).map(\.cluster)
            ),
            characters.map(\.span)
        )
    }
}
