//
//  Typesetter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Each run is shaped on its own, in shaping runs of one embedding level and one orientation each, and lines break by
// UAX #14 over the text of all runs together, in logical order. A line's glyphs are cut into groups by the characters
// they are set from, and a group's glyphs belong to the first character they are set from. Each line is then ordered by
// UAX #9: its groups lie from left to right in the visual order of their first characters, and tracking lies between
// every two neighbouring characters as placed, the tracking of whichever comes first in the text, so it widens no line
// past its outermost characters and moves no centred or right-aligned line off its place, but between two letters of
// one cursive script, whose connection it would break. Which character a character is drawn with, where a highlight or
// underline piece is cut and which glyph run holds it are those `PlacedLine` gives.
struct Typesetter: Sendable {
    // MARK: - Property
    private let shaper: any ShapingProvider
    private let breaker = LineBreaker()
    private let segmenter = WordSegmenter()
    private let finder = UnitFinder()
    private let resolver = BidiResolver()

    // MARK: - Initializer
    init(shaper: any ShapingProvider) {
        self.shaper = shaper
    }

    // MARK: - Public
    // `width` is the width of the text box in output pixels, and the text wraps at it with each run at its widest
    // tracking, while glyphs are placed at its static tracking. Without it the text breaks only at `\n` and the box
    // is as wide as the widest line. A piece of a word wider than `width` that cannot break widens the box to hold it.
    // Text that takes more lines than its paragraph style's `lines`, counting every `\n`, stops. A style of one line
    // wraps at no width, and is too wide when it is wider than `width`. The text is laid out in line coordinates, which
    // its style's writing mode turns into the box's, `width` its inline size. Lines lie the line height apart, baseline
    // to baseline, stacked from the block-start edge: the first baseline lies its line's largest extent on the side
    // facing that edge inside it, and the box ends the last line's largest extent on the side facing block-end past the
    // last. `unit` splits the text into units, for a title animated by unit. The text is laid out in its style's
    // direction, `auto` taking it from the first paragraph that holds a strong character, and its lines are aligned
    // along the inline axis by its style's `align`, or on the side that direction starts from.
    func layout(
        _ runs: [TextRun],
        paragraph style: ParagraphStyle,
        width: Double?,
        unit: TextUnit? = nil,
        place: Place,
        kind: String
    ) throws -> TextLayout {
        let runs = clustered(runs)
        let text = runs.map(\.text).joined()
        let scalars = Array(text.unicodeScalars)
        let paragraphLevel = style.direction?.paragraphLevel ?? resolver.paragraphLevel(of: scalars) ?? 0
        let levels = resolver.levels(of: scalars, paragraphLevel: paragraphLevel)
        let direction = TextDirection(level: paragraphLevel)
        let align = style.align ?? direction.start
        let isOneLine = style.lines == 1
        let lines = try paragraphs(of: runs).flatMap { paragraph in
            try self.lines(
                of: paragraph.pieces,
                from: paragraph.start,
                levels: levels,
                paragraphLevel: paragraphLevel,
                writingMode: style.writingMode,
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

        let writingMode = style.writingMode
        let padding = style.background?.padding ?? Size(width: 0, height: 0)
        let startExtent = writingMode.startExtent(ascent: lines.first?.ascent ?? 0, descent: lines.first?.descent ?? 0)
        let endExtent = writingMode.endExtent(ascent: lines.last?.ascent ?? 0, descent: lines.last?.descent ?? 0)
        let textHeight = Double(max(lines.count - 1, 0)) * style.lineHeight + startExtent + endExtent
        let blockSize = textHeight + padding.height * 2
        let firstBaseline = padding.height + startExtent
        var placedRuns: [GlyphRun] = []
        var placedLines: [PlacedLine] = []
        var spans: [[ClosedRange<Double>]] = []
        for (index, line) in lines.enumerated() {
            let origin = Point(
                x: padding.width + align.offset(of: line.width, in: textWidth),
                y: writingMode.block(fromStart: firstBaseline + Double(index) * style.lineHeight, in: blockSize)
            )
            let placed = placed(
                line,
                index: index,
                origin: origin,
                firstRun: placedRuns.count,
                paragraphLevel: paragraphLevel,
                writingMode: writingMode
            )
            placedRuns += placed.runs
            placedLines.append(placed.line)
            spans.append(placed.spans)
        }
        placedRuns = decorated(placedRuns, lines: placedLines, spans: spans, styles: runs, writingMode: writingMode)

        let words = text.scalarRanges(of: segmenter.words(of: Array(text)))

        return TextLayout(
            text: text,
            words: words,
            size: writingMode.turned(Size(width: textWidth + padding.width * 2, height: blockSize)),
            textBox: writingMode.turned(Rectangle(x: padding.width, y: padding.height, width: textWidth, height: textHeight)),
            width: width,
            lines: placedLines,
            runs: placedRuns,
            units: unit.map { unit in
                finder.units(
                    by: unit,
                    text: text,
                    words: words,
                    lines: placedLines,
                    spans: spans,
                    runs: placedRuns,
                    writingMode: writingMode
                )
            },
            background: style.background,
            writingMode: writingMode,
            direction: direction,
            align: align,
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
    // scalar in the text of all runs, and `levels` the embedding level of each scalar of that text. A line is measured
    // as it is placed, its characters ordered at `paragraphLevel`, and shaped as `writingMode` sets it.
    private func lines(
        of paragraph: [(source: Int, run: TextRun)],
        from start: Int,
        levels: [Int],
        paragraphLevel: Int,
        writingMode: WritingMode,
        width: Double?,
        place: Place,
        kind: String
    ) throws -> [TextLine] {
        let scalars = paragraph.flatMap { Array($0.run.text.unicodeScalars) }
        let characters = try shaped(
            paragraph,
            from: start,
            levels: levels,
            writingMode: writingMode,
            place: place,
            kind: kind
        )
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
            let isTooWide = width.map { breakWidth(of: word, paragraphLevel: paragraphLevel) > $0 } ?? false
            if isTooWide && !current.isEmpty {
                lines.append(current)
                current = []
            }

            for piece in isTooWide ? pieces(of: word, from: start, breaks: breaks) : [word] {
                let candidate = current + piece
                let overflows = width.map { room in
                    !current.isEmpty && breakWidth(of: candidate, paragraphLevel: paragraphLevel) > room
                }

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
        let home = paragraph.first.map { first in
            [TextExtent(face: first.run.faces[0], size: first.run.style.size, writingMode: writingMode)]
        } ?? []
        return lines.map { characters in
            let glyphs = characters.flatMap(\.glyphs)
            let extents = glyphs.isEmpty
                ? home
                : glyphs.map { TextExtent(face: $0.face, size: $0.style.size, writingMode: writingMode) }
            let visible = visibleCharacters(of: characters)
            let first = visible.first?.range.lowerBound ?? characters.first?.range.lowerBound ?? start

            return TextLine(
                characters: characters,
                range: first..<(visible.last?.range.upperBound ?? first),
                width: visibleWidth(of: characters, tracking: \.tracking, paragraphLevel: paragraphLevel),
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

    // Each run is shaped on its own in shaping runs, stretches of its characters at one embedding level and one
    // orientation, since a run boundary, a change of level and, in a vertical `writingMode`, a change between upright
    // and sideways each end a shaping run, and its glyphs are told by the scalar they start at in the whole paragraph.
    // In a horizontal line no character is upright or sideways. Each character is a grapheme cluster of its run, its
    // range counted from `start`, its level that of its first scalar among `levels`, and owns the glyphs of the group
    // it is the first character of, in the order the provider gave them. A shaping run's glyphs are grouped in the
    // order it is read, from its right end at an odd level.
    private func shaped(
        _ paragraph: [(source: Int, run: TextRun)],
        from start: Int,
        levels: [Int],
        writingMode: WritingMode,
        place: Place,
        kind: String
    ) throws -> [StyledCharacter] {
        var offset = 0
        var glyphs: [(glyph: StyledGlyph, isReversed: Bool)] = []
        var characters: [(character: Character, range: Range<Int>, level: Int, source: Int, run: TextRun)] = []
        for (source, run) in paragraph {
            var runCharacters: [(character: Character, range: Range<Int>, level: Int, source: Int, run: TextRun)] = []
            for character in run.text {
                let count = character.unicodeScalars.count
                runCharacters.append((character, offset..<(offset + count), levels[start + offset], source, run))
                offset += count
            }
            let uprights = runCharacters.map { writingMode.isVertical && isUpright($0.character) }

            for stretch in stretches(levels: runCharacters.map(\.level), uprights: uprights) {
                let direction = TextDirection(level: runCharacters[stretch.lowerBound].level)
                let isUpright = uprights[stretch.lowerBound]
                let text = String(runCharacters[stretch].map(\.character))
                let shapingStart = runCharacters[stretch.lowerBound].range.lowerBound
                let shapedRuns = try Result { try shape(text, direction: direction, upright: isUpright, run: run) }
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
                let laid = shapedRuns.flatMap { shaped in
                    shaped.glyphs.map { glyph in
                        StyledGlyph(
                            glyph: ShapedGlyph(
                                id: glyph.id,
                                advance: glyph.advance,
                                offset: glyph.offset + shapingStart,
                                placementOffset: glyph.placementOffset
                            ),
                            face: shaped.face,
                            isSideways: writingMode.isVertical && !isUpright,
                            source: source,
                            style: run.style,
                            runFace: run.faces[0]
                        )
                    }
                }
                let isReversed = direction == .rtl
                glyphs += (isReversed ? Array(laid.reversed()) : laid).map { (glyph: $0, isReversed: isReversed) }
            }
            characters += runCharacters
        }

        let owned = owners(ofGlyphsAt: glyphs.map(\.glyph.glyph.offset), in: characters.map(\.range))
        return zip(characters, owned).map { element, indices in
            let (character, range, level, source, run) = element
            let em = run.style.size / 1000
            let isOwner = !indices.isEmpty
            let given = indices.first.map { glyphs[$0].isReversed } == true ? Array(indices.reversed()) : indices

            return StyledCharacter(
                character: character,
                range: (range.lowerBound + start)..<(range.upperBound + start),
                level: level,
                source: source,
                style: run.style,
                runFace: run.faces[0],
                glyphs: given.map { glyphs[$0].glyph },
                isSpace: character.unicodeScalars.isSpace,
                tracking: isOwner ? run.style.tracking * em : 0,
                widestTracking: isOwner ? run.widestTracking * em : 0,
                cursiveScripts: cursiveScripts(of: character)
            )
        }
    }

    // The stretches of characters at one level, among `levels`, and one orientation, among `uprights`, as ranges of
    // their indices.
    private func stretches(
        levels: [Int],
        uprights: [Bool]
    ) -> [Range<Int>] {
        levels.indices.reduce(into: [Range<Int>]()) { stretches, index in
            if let last = stretches.last,
                levels[last.lowerBound] == levels[index], uprights[last.lowerBound] == uprights[index] {
                stretches[stretches.count - 1] = last.lowerBound..<(index + 1)
            } else {
                stretches.append(index..<(index + 1))
            }
        }
    }

    // The glyphs each character owns, by index. Each glyph is taken with the character its scalar is in, the glyphs
    // are cut into groups where that character changes, and neighbouring groups merge until every character of a
    // group comes before every character of the next. A group's glyphs belong to the first character they are set
    // from, and every other character owns none.
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
        for group in groups {
            owned[group.first] = group.glyphs
        }

        return owned
    }

    // `text` of `run` set in `direction`, `upright` in a vertical line or as horizontal text, with the style's features
    // over `kern`, which `kerning` sets, and over the optional ligatures, off in a run spaced apart. A later setting of
    // a tag replaces an earlier one.
    private func shape(
        _ text: String,
        direction: TextDirection,
        upright: Bool,
        run: TextRun
    ) throws -> [ShapedRun] {
        let style = run.style
        let ligatures = run.isSpacedApart ? ["liga", "clig", "dlig"].map { FontFeature(tag: $0, value: 0) } : []
        let settings = [FontFeature(tag: "kern", value: style.isKerned ? 1 : 0)] + ligatures + style.features
        let features = settings.reduce(into: [FontFeature]()) { features, feature in
            features.removeAll { $0.tag == feature.tag }
            features.append(feature)
        }

        return try shaper.shape(
            text,
            direction: direction,
            upright: upright,
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

    // The levels of a line's characters after rule L1 of UAX #9, each its first scalar's, the spaces that hang at
    // `paragraphLevel`, which puts them on the side the line ends on.
    private func lineLevels(
        of characters: [StyledCharacter],
        paragraphLevel: Int
    ) -> [Int] {
        let scalars = characters.flatMap { Array($0.character.unicodeScalars) }
        let levels = characters.flatMap { Array(repeating: $0.level, count: $0.character.unicodeScalars.count) }
        let lineLevels = resolver.lineLevels(
            of: scalars,
            levels: levels,
            lines: [scalars.indices],
            paragraphLevel: paragraphLevel
        )
        let visibleCount = visibleCharacters(of: characters).count
        var first = 0

        return characters.enumerated().map { index, character in
            defer { first += character.character.unicodeScalars.count }

            return index < visibleCount ? lineLevels[first] : paragraphLevel
        }
    }

    // Whether a character stands upright in a vertical line: by the Vertical_Orientation of its first scalar, as
    // UAX #50 orients a grapheme cluster, and always when it holds an enclosing mark, which a turned base would leave.
    private func isUpright(_ character: Character) -> Bool {
        guard let first = character.unicodeScalars.first else { return false }
        let isEnclosed = character.unicodeScalars.contains { $0.properties.generalCategory == .enclosingMark }

        return isEnclosed || VerticalOrientation(first).isUpright
    }

    // The cursive scripts a character is a letter of: those of its first scalar when it is a letter or a number, as CSS
    // Text 3 takes a typographic character unit's properties from its first scalar, and none otherwise.
    private func cursiveScripts(of character: Character) -> [String] {
        guard let scalar = character.unicodeScalars.first else { return [] }

        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .decimalNumber,
            .letterNumber, .otherNumber:
            return CursiveScript.codes(of: scalar)

        default:
            return []
        }
    }

    // A line's characters and hanging spaces with glyphs of their own in the order they are placed in, each with the
    // character whose run's tracking lies on its left, as `PlacedLine.placedOwners` gives them.
    private func placedOwners(
        of characters: [StyledCharacter],
        paragraphLevel: Int
    ) -> [(index: Int, tracking: Int?)] {
        PlacedLine.placedOwners(
            levels: lineLevels(of: characters, paragraphLevel: paragraphLevel),
            hasGlyphs: characters.map { !$0.glyphs.isEmpty },
            characterCount: visibleCharacters(of: characters).count,
            cursiveScripts: characters.map(\.cursiveScripts)
        )
    }

    // The advances of the visible characters and the tracking between every two of them that `placedOwners` gives.
    private func visibleWidth(
        of characters: [StyledCharacter],
        tracking: KeyPath<StyledCharacter, Double>,
        paragraphLevel: Int
    ) -> Double {
        let gaps = placedOwners(of: characters, paragraphLevel: paragraphLevel)
            .compactMap { $0.tracking.map { characters[$0][keyPath: tracking] } }

        return visibleCharacters(of: characters).map(\.advance).reduce(0, +) + gaps.reduce(0, +)
    }

    private func breakWidth(
        of characters: [StyledCharacter],
        paragraphLevel: Int
    ) -> Double {
        visibleWidth(of: characters, tracking: \.widestTracking, paragraphLevel: paragraphLevel)
    }

    // Glyphs of one line of one text run in one face and one orientation that lie side by side make one glyph run, and
    // the runs of a line share its baseline, which `origin` gives with the line's start in line coordinates. The
    // groups of glyphs lie in the order `placedOrder` gives, each glyph at the pen with its placement offset, a sideways
    // glyph's moved toward line-under onto its face's alphabetic baseline, both turned into the box's coordinates by
    // `writingMode`, and the pen moves from left to right by advances and by the tracking
    // `PlacedLine.placedOwners` puts between neighbouring characters, so the spaces that hang lie past the line's end
    // untracked: after its right end, or before its left end at an odd paragraph level, where L2 places them first, on
    // a line with no character too. A character with no glyph of its own is a range of count 0 after the glyphs of the
    // character `PlacedLine.owners(hasGlyphs:)` draws it with and spans that character, and on a line with no glyph it
    // is a range of count 0 at glyph 0 of the line's first run, written for it with no glyphs, spanning nothing at the
    // line's start. The hanging spaces, which are no characters, are cut into groups among themselves. A character's
    // span is its glyph box along the line, from the pen where its glyphs begin, as long as their advances, and the
    // spans of the line's characters are given in text order, in line coordinates. The line's clusters name glyphs by the index of their run
    // among the text's, the first of this line's runs being `firstRun`, and carry their levels after rule L1 and their
    // cursive scripts. `index` is the line's among the text's.
    private func placed(
        _ line: TextLine,
        index lineIndex: Int,
        origin: Point,
        firstRun: Int,
        paragraphLevel: Int,
        writingMode: WritingMode
    ) -> (
        runs: [GlyphRun],
        line: PlacedLine,
        spans: [ClosedRange<Double>]
    ) {
        let characters = line.characters
        let visibleCount = visibleCharacters(of: characters).count
        let levels = lineLevels(of: characters, paragraphLevel: paragraphLevel)
        let hasGlyphs = characters.map { !$0.glyphs.isEmpty }
        let order = PlacedLine.placedOrder(levels: levels, hasGlyphs: hasGlyphs)
        let placedOwners = PlacedLine.placedOwners(
            levels: levels,
            hasGlyphs: hasGlyphs,
            characterCount: visibleCount,
            cursiveScripts: characters.map(\.cursiveScripts)
        )
        let hangingOwners = PlacedLine.owners(hasGlyphs: Array(hasGlyphs.dropFirst(visibleCount)))
        let owners = PlacedLine.owners(hasGlyphs: Array(hasGlyphs.prefix(visibleCount)))
            + hangingOwners.map { $0.map { visibleCount + $0 } }
        let leading = TextDirection(level: paragraphLevel) == .rtl ? order.filter { $0 >= visibleCount } : []

        var runs: [GlyphRun] = []
        var groups: [Int: (glyphs: GlyphRange, span: ClosedRange<Double>)] = [:]
        var x = origin.x - leading.map { characters[$0].advance }.reduce(0, +)
        for (index, owner) in placedOwners {
            let character = characters[index]
            x += owner.map { characters[$0].tracking } ?? 0

            let start = x
            for glyph in character.glyphs {
                let pen = writingMode.turned(Point(x: x, y: origin.y))
                let offset = glyph.glyph.placementOffset
                let under = glyph.isSideways
                    ? offset.y + TextExtent(face: glyph.face, size: glyph.style.size, writingMode: writingMode).alphabetic
                    : offset.y
                let positioned = PositionedGlyph(
                    id: glyph.glyph.id,
                    x: pen.x,
                    y: pen.y,
                    placementOffset: writingMode.turned(Point(x: offset.x, y: writingMode.lineUnder * under))
                )
                x += glyph.glyph.advance

                if let previous = runs.last, previous.source == glyph.source, previous.face == glyph.face,
                    previous.isSideways == glyph.isSideways {
                    runs[runs.count - 1] = GlyphRun(
                        source: previous.source,
                        line: lineIndex,
                        face: previous.face,
                        size: previous.size,
                        glyphs: previous.glyphs + [positioned],
                        isSideways: previous.isSideways,
                        staticTracking: previous.staticTracking
                    )
                } else {
                    runs.append(GlyphRun(
                        source: glyph.source,
                        line: lineIndex,
                        face: glyph.face,
                        size: glyph.style.size,
                        glyphs: [positioned],
                        isSideways: glyph.isSideways,
                        staticTracking: glyph.style.tracking * glyph.style.size / 1000
                    ))
                }
            }

            let count = character.glyphs.count
            let first = runs[runs.count - 1].glyphs.count - count
            groups[index] = (GlyphRange(run: firstRun + runs.count - 1, first: first, count: count), start...x)
        }

        if let character = characters.first, groups.isEmpty {
            runs.append(GlyphRun(
                source: character.source,
                line: lineIndex,
                face: character.runFace,
                size: character.style.size,
                glyphs: [],
                staticTracking: character.style.tracking * character.style.size / 1000
            ))
        }
        let placed = characters.enumerated().map { index, character in
            let held = owners[index].flatMap { groups[$0] }
                ?? (GlyphRange(run: firstRun, first: 0, count: 0), origin.x...origin.x)
            let isOwner = owners[index] == index
            let glyphs = isOwner
                ? held.glyphs
                : GlyphRange(run: held.glyphs.run, first: held.glyphs.first + held.glyphs.count, count: 0)
            let cluster = PlacedCluster(
                glyphs: glyphs,
                range: character.range,
                advance: isOwner ? character.advance : 0,
                level: levels[index],
                cursiveScripts: character.cursiveScripts
            )

            return (cluster: cluster, span: held.span)
        }

        return (
            runs,
            PlacedLine(
                width: line.width,
                baseline: origin.y,
                ascent: line.ascent,
                descent: line.descent,
                range: line.range,
                clusters: placed.prefix(visibleCount).map(\.cluster),
                hanging: placed.dropFirst(visibleCount).map(\.cluster)
            ),
            placed.prefix(visibleCount).map(\.span)
        )
    }

    // `runs` with the highlight and underline pieces of the text runs `styles` gives, by index: on each of `lines`, one
    // piece for each stretch of a text run's characters `PlacedLine.pieces(of:sources:)` gives, from the start of the
    // span among `spans` of its leftmost character to the end of its rightmost one's, held by the glyph run
    // `PlacedLine.holder(of:sources:)` names. A highlight piece runs from the text run's ascent on the line-over side of
    // the line's baseline to its descent on the line-under side, in its first face at its size, and an underline piece
    // lies on its alphabetic baseline, both in the box's coordinates.
    private func decorated(
        _ runs: [GlyphRun],
        lines: [PlacedLine],
        spans: [[ClosedRange<Double>]],
        styles: [TextRun],
        writingMode: WritingMode
    ) -> [GlyphRun] {
        let sources = runs.map(\.source)
        var decorated = runs
        for (index, line) in lines.enumerated() {
            for holder in Set(line.clusters.map(\.glyphs.run))
            where line.holder(of: runs[holder].source, sources: sources) == holder {
                let run = runs[holder]
                let style = styles[run.source].style
                let extent = TextExtent(face: styles[run.source].faces[0], size: style.size, writingMode: writingMode)
                let pieces = line.pieces(of: run.source, sources: sources).map { characters in
                    spans[index][characters[0]].lowerBound...spans[index][characters[characters.count - 1]].upperBound
                }
                decorated[holder] = GlyphRun(
                    source: run.source,
                    line: run.line,
                    face: run.face,
                    size: run.size,
                    glyphs: run.glyphs,
                    isSideways: run.isSideways,
                    staticTracking: run.staticTracking,
                    highlights: style.isHighlighted ? pieces.map { piece in
                        writingMode.turned(Rectangle(
                            x: piece.lowerBound,
                            y: writingMode.blockStart(around: line.baseline, over: extent.ascent, under: extent.descent),
                            width: piece.upperBound - piece.lowerBound,
                            height: extent.ascent + extent.descent
                        ))
                    } : [],
                    underlines: style.isUnderlined ? pieces.map { piece in
                        let start = writingMode.turned(Point(
                            x: piece.lowerBound,
                            y: writingMode.block(extent.alphabetic, under: line.baseline)
                        ))

                        return UnderlinePiece(x: start.x, y: start.y, width: piece.upperBound - piece.lowerBound)
                    } : []
                )
            }
        }

        return decorated
    }
}
