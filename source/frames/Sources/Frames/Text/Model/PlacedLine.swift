//
//  PlacedLine.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A line as it is set: its width at the static tracking, the y of its baseline in the text's box at the static line
// height, the largest ascent and descent among its runs, and its range of the title's text. `clusters` are its
// characters, its grapheme clusters up to the last one that is not a space, and `hanging` the spaces after them, which
// hang past its end and are no character, both in text order. A line with no character has the empty range where it
// starts.
struct PlacedLine: Equatable, Sendable {
    // MARK: - Property
    let width: Double
    let baseline: Double
    let ascent: Double
    let descent: Double
    let range: Range<Int>
    let clusters: [PlacedCluster]
    let hanging: [PlacedCluster]

    // Its clusters followed by its hanging spaces, by their index among them, in the order they are placed in.
    var placedOrder: [Int] {
        let placed = clusters + hanging

        return Self.placedOrder(levels: placed.map(\.level), hasGlyphs: placed.map { $0.glyphs.count > 0 })
    }

    // Its clusters and hanging spaces with glyphs of their own in the order they are placed in, each with the character
    // whose run's tracking lies on its left, as the static `placedOwners` gives them.
    var placedOwners: [(index: Int, tracking: Int?)] {
        let placed = clusters + hanging

        return Self.placedOwners(
            levels: placed.map(\.level),
            hasGlyphs: placed.map { $0.glyphs.count > 0 },
            characterCount: clusters.count,
            cursiveScripts: placed.map(\.cursiveScripts)
        )
    }

    // MARK: - Initializer
    init(
        width: Double,
        baseline: Double,
        ascent: Double,
        descent: Double,
        range: Range<Int>,
        clusters: [PlacedCluster],
        hanging: [PlacedCluster]
    ) {
        self.width = width
        self.baseline = baseline
        self.ascent = ascent
        self.descent = descent
        self.range = range
        self.clusters = clusters
        self.hanging = hanging
    }

    // MARK: - Public
    // The character whose glyphs each of a line's characters is drawn with, by index, `hasGlyphs` saying which have
    // glyphs of their own. A line is cut into groups only at the first character of each group after its first, so a
    // group holds its first character and those after it up to the next group's, and the line's first group those
    // before it too. A character with glyphs of its own is drawn with them, every other with its group's first
    // character's, and on a line with no glyph each is nil.
    static func owners(hasGlyphs: [Bool]) -> [Int?] {
        var owner = hasGlyphs.firstIndex(of: true)

        return hasGlyphs.indices.map { index in
            owner = hasGlyphs[index] ? index : owner

            return owner
        }
    }

    // The order a line's characters are placed in from left to right, by their index: each group of glyphs, as
    // `owners(hasGlyphs:)` cuts them, where rule L2 of UAX #9 puts its first character among `levels`, the characters'
    // levels on the line, with its characters in text order. A line with no glyph has its characters in text order.
    static func placedOrder(
        levels: [Int],
        hasGlyphs: [Bool]
    ) -> [Int] {
        guard hasGlyphs.contains(true) else { return Array(hasGlyphs.indices) }
        let owners = Self.owners(hasGlyphs: hasGlyphs)
        let groups = Dictionary(grouping: hasGlyphs.indices) { owners[$0] ?? 0 }

        return BidiResolver.visualOrder(of: levels).filter { hasGlyphs[$0] }.flatMap { groups[$0] ?? [] }
    }

    // A line's characters and hanging spaces with glyphs of their own, by their index among `levels`, in the order
    // `placedOrder(levels:hasGlyphs:)` places them, the first `characterCount` being characters and the rest hanging
    // spaces. Each comes with `tracking`, the character whose run's tracking lies between it and its neighbour on its
    // left: whichever of the two comes first in the text when both are characters, and nil otherwise or when both are
    // letters of one cursive script among `cursiveScripts`, since tracking there would break the connection a cursive
    // script draws across the two, as CSS Text 3 spaces no two letters of a cursive script apart.
    static func placedOwners(
        levels: [Int],
        hasGlyphs: [Bool],
        characterCount: Int,
        cursiveScripts: [[String]]
    ) -> [(index: Int, tracking: Int?)] {
        let owners = placedOrder(levels: levels, hasGlyphs: hasGlyphs).filter { hasGlyphs[$0] }

        return owners.indices.map { order in
            let index = owners[order]
            guard order > 0 else { return (index, nil) }
            let neighbour = owners[order - 1]
            guard
                neighbour < characterCount,
                index < characterCount,
                Set(cursiveScripts[neighbour]).isDisjoint(with: cursiveScripts[index])
            else {
                return (index, nil)
            }

            return (index, min(neighbour, index))
        }
    }

    // The index of the character whose glyphs the character at `index` is drawn with, as `owners(hasGlyphs:)` gives it
    // among the line's characters.
    func owner(of index: Int) -> Int? {
        Self.owners(hasGlyphs: clusters.map { $0.glyphs.count > 0 })[index]
    }

    // The index of the glyph run that holds the highlight and underline pieces of the text run at `source` on the
    // line: the first of the glyph runs its characters are drawn from, `sources` giving the text run of each glyph run,
    // so a space that hangs past the line's end holds none. A text run with no character on the line has none.
    func holder(
        of source: Int,
        sources: [Int]
    ) -> Int? {
        clusters.map(\.glyphs.run).filter { sources[$0] == source }.min()
    }

    // The characters of each piece of the highlight and underline of the text run at `source` on the line, by their
    // index among its clusters, as they are placed from left to right: each stretch of its characters that lie side by
    // side, the stretches in the text order of their first characters, as the pieces are. A character is of the text
    // run of the glyph run its glyphs name, a character with no glyph of its own its group's first character's, and
    // `sources` gives the text run of each glyph run.
    func pieces(
        of source: Int,
        sources: [Int]
    ) -> [[Int]] {
        var stretches: [(source: Int, characters: [Int])] = []
        for index in placedOrder where index < clusters.count {
            let characterSource = sources[clusters[index].glyphs.run]
            if stretches.last?.source == characterSource {
                stretches[stretches.count - 1].characters.append(index)
            } else {
                stretches.append((characterSource, [index]))
            }
        }

        return stretches.filter { $0.source == source }.map(\.characters).sorted { ($0.min() ?? 0) < ($1.min() ?? 0) }
    }

    // MARK: - Private
}
