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
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `text` is the text every range counts, `words` its words in reading order, each its range, `spans` the glyph box
    // span across its line of each character of each line, and `runs` the text's glyph runs, which hold the highlight
    // and underline pieces.
    func units(
        by unit: TextUnit,
        text: String,
        words: [Range<Int>],
        lines: [PlacedLine],
        spans: [[ClosedRange<Double>]],
        runs: [GlyphRun]
    ) -> [PlacedUnit] {
        let scalars = Array(text.unicodeScalars)
        let spaces = lines.map { line in line.clusters.map { scalars[$0.range].isSpace } }
        let stretches = lines.enumerated().flatMap { index, line in
            self.stretches(of: line, spaces: spaces[index], words: words, by: unit)
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
            let held = range(of: stretch).filter { !spaces[stretch.line][$0] }
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
    // The stretches of a line's characters that go with its units, in order. Each unit holds the characters `held`
    // gives it, and the characters after its first up to the next unit's first go with it, the line's first unit also
    // taking those before it. A unit whose first character is a later character of a group of glyphs joins the unit
    // before it, which the group's first character goes with. `spaces` says which of the line's characters are spaces.
    private func stretches(
        of line: PlacedLine,
        spaces: [Bool],
        words: [Range<Int>],
        by unit: TextUnit
    ) -> [Range<Int>] {
        let starts = held(of: line, spaces: spaces, words: words, by: unit).compactMap(\.first)
            .reduce(into: [Int]()) { starts, start in
                let isLater = line.clusters[start].glyphs.count == 0
                    && line.clusters[..<start].contains { $0.glyphs.count > 0 }
                if starts.isEmpty || !isLater {
                    starts.append(start)
                }
            }

        return starts.indices.map { index in
            let start = index == 0 ? 0 : starts[index]
            let end = starts.indices.contains(index + 1) ? starts[index + 1] : line.clusters.count

            return start..<end
        }
    }

    // The characters each unit of a line holds, by their index, in order. A word holds the characters of its range on
    // the line but its spaces, so a word a line breaks inside is a unit on each line. A character in no word goes with
    // the unit before it, and a character that is not a space, on a line that would hold no unit, is a unit of its own.
    private func held(
        of line: PlacedLine,
        spaces: [Bool],
        words: [Range<Int>],
        by unit: TextUnit
    ) -> [[Int]] {
        let visible = spaces.indices.filter { !spaces[$0] }
        let groups: [[Int]]
        switch unit {
        case .character:
            groups = visible.map { [$0] }

        case .word:
            groups = words.filter { $0.overlaps(line.range) }.compactMap { word in
                let held = visible.filter { word.contains(line.clusters[$0].range.lowerBound) }

                return held.isEmpty ? nil : held
            }

        case .line:
            groups = visible.isEmpty ? [] : [visible]
        }

        return groups.isEmpty ? visible.map { [$0] } : groups
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
