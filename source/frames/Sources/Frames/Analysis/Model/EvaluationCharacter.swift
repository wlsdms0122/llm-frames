//
//  EvaluationCharacter.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// One character an item of `evaluate` reports: its text, its `[start, end)` in Unicode scalars over its title's text,
// the embedding level it lies at on its line, its glyph box at the time and the y of the baseline it sits on, its x in
// a vertical writing mode, both in its title's text box at the time.
package struct EvaluationCharacter: Equatable, Sendable {
    // MARK: - Property
    package let text: String
    package let range: Range<Int>
    package let level: Int
    package let rect: Rectangle
    package let baseline: Double

    // MARK: - Initializer
    init(
        text: String,
        range: Range<Int>,
        level: Int,
        rect: Rectangle,
        baseline: Double
    ) {
        self.text = text
        self.range = range
        self.level = level
        self.rect = rect
        self.baseline = baseline
    }

    // MARK: - Public
    // MARK: - Private
}
