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

        return Self.placedOrder(levels: placed.map(\.level), owners: placed.map { $0.glyphs.count > 0 })
    }

    // Its clusters and hanging spaces with glyphs of their own, by their index among them, in the order they are placed
    // in, each with `tracking`, the character whose run's tracking lies between it and its neighbour on its left:
    // whichever of the two comes first in the text when both are characters, and nil otherwise.
    var placedOwners: [(index: Int, tracking: Int?)] {
        let placed = clusters + hanging
        let owners = placedOrder.filter { placed[$0].glyphs.count > 0 }

        return owners.indices.map { order in
            let index = owners[order]
            guard order > 0, owners[order - 1] < clusters.count, index < clusters.count else { return (index, nil) }

            return (index, min(owners[order - 1], index))
        }
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
    // The order a line's characters are placed in from left to right, by their index: each group of glyphs where rule
    // L2 of UAX #9 puts its first character among `levels`, the characters' levels on the line, followed by its later
    // characters in text order, the first group of the line holding the characters before it. `owners` says which
    // characters have glyphs of their own, and a line with none has its characters in text order.
    static func placedOrder(
        levels: [Int],
        owners: [Bool]
    ) -> [Int] {
        let firsts = owners.indices.filter { owners[$0] }
        guard let leading = firsts.first else { return Array(owners.indices) }
        let ends = Dictionary(uniqueKeysWithValues: zip(firsts, Array(firsts.dropFirst()) + [owners.count]))

        return BidiResolver().visualOrder(of: levels).filter { owners[$0] }.flatMap { first in
            Array((first == leading ? 0 : first)..<ends[first, default: owners.count])
        }
    }

    // The index of the character whose glyphs the character at `index` is drawn with: itself when it has glyphs of its
    // own, and otherwise its group's first character, the nearest before it with glyphs, or nil when none is before it.
    func owner(of index: Int) -> Int? {
        clusters[...index].lastIndex { $0.glyphs.count > 0 }
    }

    // The characters of each piece of the highlight and underline of the text run at `source` on the line, by their
    // index among its clusters, as they are placed from left to right: each stretch of its characters that lie side by
    // side, the stretches in the text order of their first characters, as the pieces are. A character is of the text
    // run of the glyph run its glyphs name, and `sources` gives the text run of each glyph run.
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
