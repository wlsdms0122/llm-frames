//
//  GlyphRange.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Glyphs of the text's glyph runs as they are placed on a line: `count` glyphs from glyph `first` of the glyph run at
// index `run` among the text's and on into the runs after it, as a group of glyphs set in two faces lies in a run of
// each. A later character of a group of glyphs, as a ligature sets two characters in one glyph, is a range of count 0
// after the group's last glyph, in the run that glyph lies in.
struct GlyphRange: Equatable, Sendable {
    // MARK: - Property
    let run: Int
    let first: Int
    let count: Int

    // MARK: - Initializer
    init(
        run: Int,
        first: Int,
        count: Int
    ) {
        self.run = run
        self.first = first
        self.count = count
    }

    // MARK: - Public
    // The indices of its glyphs among its run's glyphs, for a range that lies in its run.
    var glyphs: Range<Int> {
        first..<(first + count)
    }

    // Its glyphs as ranges that each lie in one glyph run, in the order they are placed, `glyphCounts` giving the glyph
    // count of each of the text's glyph runs. They hold fewer than `count` glyphs where the runs end before it does,
    // and none where glyph `first` is not one of its run's.
    func ranges(within glyphCounts: [Int]) -> [GlyphRange] {
        guard glyphCounts.indices.contains(run), first < glyphCounts[run] else { return [] }

        var ranges: [GlyphRange] = []
        var start = first
        var remaining = count
        for index in glyphCounts.indices.dropFirst(run) {
            guard remaining > 0 else { break }

            let taken = min(remaining, glyphCounts[index] - start)
            if taken > 0 {
                ranges.append(GlyphRange(run: index, first: start, count: taken))
            }
            start = 0
            remaining -= taken
        }

        return ranges
    }

    // MARK: - Private
}
