//
//  PlacedUnit.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A unit of a title animated by unit. `characters` are the characters that go with it, those it holds and the spaces
// that go with it, one stretch of one line, and `hangingLines` the lines, in order, whose hanging spaces it draws.
// `glyphs` are the glyphs it draws, those of every cluster of the stretch and of every hanging space of those lines, as
// ranges of the text's glyph runs in that order. `parts` are the parts of highlight and underline pieces it carries.
// Both boxes lie in the text's box: `glyphBox` runs across the characters it holds and down its line, without their
// strokes, and `box` is the box its motion acts about, as set its glyph box, as resolved also holding their strokes and
// its parts at their widest.
struct PlacedUnit: Equatable, Sendable {
    // MARK: - Property
    let characters: CharacterRange
    let hangingLines: [Int]
    let glyphs: [GlyphRange]
    let glyphBox: Rectangle
    let box: Rectangle
    let parts: [UnitPart]

    // MARK: - Initializer
    // `lines` are the text's lines, which `characters` and `hangingLines` name.
    init(
        characters: CharacterRange,
        hangingLines: [Int],
        lines: [PlacedLine],
        glyphBox: Rectangle,
        box: Rectangle,
        parts: [UnitPart]
    ) {
        let stretch = lines[characters.line].clusters[characters.clusters]
        let clusters = Array(stretch) + hangingLines.flatMap { lines[$0].hanging }

        self.characters = characters
        self.hangingLines = hangingLines
        self.glyphs = Self.glyphs(of: clusters)
        self.glyphBox = glyphBox
        self.box = box
        self.parts = parts
    }

    // MARK: - Public
    // MARK: - Private
    // Each run of glyphs as one range, neighbouring ranges of one glyph run joined.
    private static func glyphs(of clusters: [PlacedCluster]) -> [GlyphRange] {
        clusters.reduce(into: [GlyphRange]()) { ranges, cluster in
            let glyphs = cluster.glyphs
            guard glyphs.count > 0 else { return }

            if let last = ranges.last, last.run == glyphs.run, last.glyphs.upperBound == glyphs.first {
                ranges[ranges.count - 1] = GlyphRange(
                    run: last.run,
                    first: last.first,
                    count: last.count + glyphs.count
                )
            } else {
                ranges.append(glyphs)
            }
        }
    }
}
