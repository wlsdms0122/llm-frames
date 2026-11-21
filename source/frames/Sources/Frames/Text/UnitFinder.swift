//
//  UnitFinder.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Splits laid out text into the units a title animated by unit moves, in reading order. Spaces are no unit: each goes
// with the unit before it on its line, or the line's first, so the characters that go with a unit are one stretch of
// its line, and no unit crosses a line. Units that the characters of one group of glyphs go with are one unit. A line's
// hanging spaces are drawn by its last unit, and those of a line with no unit by the unit before them in reading order,
// or by the title's first unit.
struct UnitFinder: Sendable {
    // MARK: - Property
    private let segmenter = WordSegmenter()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `text` is the text every range counts, `spans` the glyph box span across its line of each character of each line,
    // and `runs` the text's glyph runs, which hold the highlight and underline pieces.
    func units(
        by unit: TextUnit,
        text: String,
        lines: [PlacedLine],
        spans: [[ClosedRange<Double>]],
        runs: [GlyphRun]
    ) -> [PlacedUnit] {
        let characters = lines.map { line in self.characters(of: line, in: text) }
        let stretches = lines.enumerated().flatMap { index, line in
            self.stretches(of: characters[index], line: line, by: unit)
                .map { CharacterRange(line: index, first: $0.lowerBound, count: $0.count) }
        }
        guard !stretches.isEmpty else { return [] }

        var hangingLines = stretches.map { _ in [Int]() }
        for (index, line) in lines.enumerated() where !line.hanging.isEmpty {
            let owner = stretches.lastIndex { $0.line == index }
                ?? stretches.lastIndex { $0.line < index }
                ?? 0
            hangingLines[owner].append(index)
        }

        var parts = stretches.map { _ in [UnitPart]() }
        for (index, run) in runs.enumerated() {
            let carriers = stretches.indices.filter { unit in
                let stretch = stretches[unit]
                return stretch.line == run.line && lines[stretch.line].clusters[range(of: stretch)].contains {
                    runs[$0.glyphs.run].source == run.source
                }
            }
            for (piece, span) in pieces(of: run).enumerated() {
                for (order, unit) in carriers.enumerated() {
                    let start = order == 0 ? span.lowerBound : glyphStart(of: stretches[unit], spans: spans)
                    let end = order == carriers.count - 1
                        ? span.upperBound
                        : glyphStart(of: stretches[carriers[order + 1]], spans: spans)
                    parts[unit].append(UnitPart(run: index, piece: piece, span: start...end))
                }
            }
        }

        return stretches.indices.map { index in
            let stretch = stretches[index]
            let line = lines[stretch.line]
            let held = range(of: stretch).filter { !isSpace(characters[stretch.line][$0]) }
            let first = held.first.map { spans[stretch.line][$0].lowerBound } ?? 0
            let last = held.last.map { spans[stretch.line][$0].upperBound } ?? first
            let box = Rectangle(
                x: first,
                y: line.baseline - line.ascent,
                width: last - first,
                height: line.ascent + line.descent
            )

            return PlacedUnit(
                characters: stretch,
                hangingLines: hangingLines[index],
                lines: lines,
                glyphBox: box,
                box: box,
                parts: parts[index]
            )
        }
    }

    // MARK: - Private
    // The text of each of a line's characters, which its range holds.
    private func characters(
        of line: PlacedLine,
        in text: String
    ) -> [Character] {
        let scalars = text.unicodeScalars
        return line.clusters.map { cluster in
            let start = scalars.index(scalars.startIndex, offsetBy: cluster.range.lowerBound)
            let end = scalars.index(start, offsetBy: cluster.range.count)

            return String(scalars[start..<end]).first ?? " "
        }
    }

    // The stretches of a line's characters that go with its units, in order. Each unit holds the characters `held`
    // gives it, and the characters after its first up to the next unit's first go with it, the line's first unit also
    // taking those before it. A unit whose first character is a later character of a group of glyphs joins the unit
    // before it, which the group's first character goes with.
    private func stretches(
        of characters: [Character],
        line: PlacedLine,
        by unit: TextUnit
    ) -> [Range<Int>] {
        let starts = held(characters, by: unit).compactMap(\.first)
            .reduce(into: [Int]()) { starts, start in
                let isLater = line.clusters[start].glyphs.count == 0
                    && line.clusters[..<start].contains { $0.glyphs.count > 0 }
                if starts.isEmpty || !isLater {
                    starts.append(start)
                }
            }

        return starts.indices.map { index in
            let start = index == 0 ? 0 : starts[index]
            let end = starts.indices.contains(index + 1) ? starts[index + 1] : characters.count

            return start..<end
        }
    }

    // The characters each unit of a line holds, by their index, in order. A character that is not a space, on a line
    // that would hold no unit, is a unit of its own.
    private func held(
        _ characters: [Character],
        by unit: TextUnit
    ) -> [[Int]] {
        let visible = characters.indices.filter { !isSpace(characters[$0]) }
        let groups: [[Int]]
        switch unit {
        case .character:
            groups = visible.map { [$0] }

        case .word:
            groups = words(of: characters)

        case .line:
            groups = visible.isEmpty ? [] : [visible]
        }

        return groups.isEmpty ? visible.map { [$0] } : groups
    }

    // A piece between word boundaries that holds a letter, a digit or an ideograph is a word. A piece of punctuation
    // or symbols, general categories P and S, with the pieces of them it touches, joins the word it touches, the one
    // before it when it touches two, and is a word of its own when it touches none. A default ignorable character takes
    // no part, and a piece of other characters is held by no word here: it goes with the unit before it on its line.
    private func words(of characters: [Character]) -> [[Int]] {
        var groups: [[Int]] = []
        var punctuation: [Int] = []
        var isAfterWord = false
        for segment in segmenter.segments(of: characters) {
            let marks = characters[segment].filter { !isIgnorable($0) }
            if marks.isEmpty {
                continue
            } else if marks.allSatisfy(isSpace) {
                if !punctuation.isEmpty {
                    groups.append(punctuation)
                    punctuation = []
                }
                isAfterWord = false
            } else if marks.contains(where: isWordCharacter) {
                groups.append(punctuation + Array(segment))
                punctuation = []
                isAfterWord = true
            } else if marks.allSatisfy(isPunctuation) {
                if isAfterWord {
                    groups[groups.count - 1] += Array(segment)
                } else {
                    punctuation += Array(segment)
                }
            }
        }
        if !punctuation.isEmpty {
            groups.append(punctuation)
        }

        return groups
    }

    // A space is a cluster whose first scalar is `White_Space`.
    private func isSpace(_ character: Character) -> Bool {
        character.unicodeScalars.first?.properties.isWhitespace ?? false
    }

    private func isIgnorable(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(\.properties.isDefaultIgnorableCodePoint)
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.first.map { scalar in
            scalar.properties.isAlphabetic
                || scalar.properties.isIdeographic
                || scalar.properties.generalCategory == .decimalNumber
        } ?? false
    }

    private func isPunctuation(_ character: Character) -> Bool {
        switch character.unicodeScalars.first?.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation,
            .finalPunctuation, .otherPunctuation, .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol:
            true

        default:
            false
        }
    }

    private func range(of stretch: CharacterRange) -> Range<Int> {
        stretch.first..<(stretch.first + stretch.count)
    }

    // Where a unit's first character's glyph box starts across its line.
    private func glyphStart(
        of stretch: CharacterRange,
        spans: [[ClosedRange<Double>]]
    ) -> Double {
        spans[stretch.line][stretch.first].lowerBound
    }

    // A run's pieces across the line, its highlight's and its underline's being the same.
    private func pieces(of run: GlyphRun) -> [ClosedRange<Double>] {
        let highlights = run.highlights.map { $0.x...($0.x + $0.width) }
        let underlines = run.underlines.map { $0.x...($0.x + $0.width) }

        return highlights.isEmpty ? underlines : highlights
    }
}
