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
    // and underline pieces. A unit's glyph box runs from the leftmost character it holds to the rightmost, and a piece
    // is cut into parts wherever two of its characters that are neighbours as placed go with different units, at the
    // glyph box of the right one, so a unit carries one part of a piece or several where its characters lie apart.
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

        var unitAt = lines.map { line in line.clusters.map { _ in 0 } }
        for (unit, stretch) in stretches.enumerated() {
            for cluster in stretch.clusters {
                unitAt[stretch.line][cluster] = unit
            }
        }

        var parts = stretches.map { _ in [UnitPart]() }
        for (index, run) in runs.enumerated() {
            let held = characters(ofPiecesOf: run, on: lines[run.line], runs: runs)
            for (piece, (span, characters)) in zip(pieces(of: run), held).enumerated() {
                var cuts: [(unit: Int, start: Double)] = []
                for character in characters where cuts.last?.unit != unitAt[run.line][character] {
                    let start = cuts.isEmpty ? span.lowerBound : spans[run.line][character].lowerBound
                    cuts.append((unitAt[run.line][character], start))
                }
                for (order, cut) in cuts.enumerated() {
                    let end = cuts.indices.contains(order + 1) ? cuts[order + 1].start : span.upperBound
                    parts[cut.unit].append(UnitPart(run: index, piece: piece, span: cut.start...end))
                }
            }
        }

        return stretches.indices.map { index in
            let stretch = stretches[index]
            let line = lines[stretch.line]
            let held = stretch.clusters.filter { !spaces[stretch.line][$0] }
            let first = held.map { spans[stretch.line][$0].lowerBound }.min() ?? 0
            let last = held.map { spans[stretch.line][$0].upperBound }.max() ?? first
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

    // The characters of each piece of `run`'s text run on `line`, by their index among its clusters, as they are placed
    // from left to right: each stretch of its characters that lie side by side, the stretches in the text order of
    // their first characters, as the pieces are. A character is of the text run of the glyph run its glyphs name.
    private func characters(
        ofPiecesOf run: GlyphRun,
        on line: PlacedLine,
        runs: [GlyphRun]
    ) -> [[Int]] {
        var stretches: [(source: Int, characters: [Int])] = []
        for index in line.placedOrder where index < line.clusters.count {
            let source = runs[line.clusters[index].glyphs.run].source
            if stretches.last?.source == source {
                stretches[stretches.count - 1].characters.append(index)
            } else {
                stretches.append((source, [index]))
            }
        }

        return stretches.filter { $0.source == run.source }.map(\.characters).sorted { ($0.min() ?? 0) < ($1.min() ?? 0) }
    }

    // A run's pieces across the line, its highlight's and its underline's being the same.
    private func pieces(of run: GlyphRun) -> [ClosedRange<Double>] {
        let highlights = run.highlights.map { $0.x...($0.x + $0.width) }
        let underlines = run.underlines.map { $0.x...($0.x + $0.width) }

        return highlights.isEmpty ? underlines : highlights
    }
}
