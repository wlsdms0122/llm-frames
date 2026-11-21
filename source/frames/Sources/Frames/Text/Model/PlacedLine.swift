//
//  PlacedLine.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A line as it is set: its width at the static tracking, the y of its baseline in the text's box at the static line
// height, the largest ascent and descent among its runs, and its range of the title's text. `clusters` are its
// characters, its grapheme clusters up to the last one that is not a space, and `hanging` the spaces after them, which
// hang past its end and are no character. A line with no character has the empty range where it starts.
struct PlacedLine: Equatable, Sendable {
    // MARK: - Property
    let width: Double
    let baseline: Double
    let ascent: Double
    let descent: Double
    let range: Range<Int>
    let clusters: [PlacedCluster]
    let hanging: [PlacedCluster]

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
    // MARK: - Private
}
