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

    // MARK: - Private
}
