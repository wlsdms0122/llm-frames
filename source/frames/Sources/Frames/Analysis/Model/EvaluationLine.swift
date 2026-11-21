//
//  EvaluationLine.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// One line of a title `evaluate` reports: its text, its `[start, end)` in Unicode scalars over its title's text, the y
// of its baseline in its title's text box at the time, with the line height then and no baseline shift, and its ascent
// and descent.
package struct EvaluationLine: Equatable, Sendable {
    // MARK: - Property
    package let text: String
    package let range: Range<Int>
    package let baseline: Double
    package let ascent: Double
    package let descent: Double

    // MARK: - Initializer
    init(
        text: String,
        range: Range<Int>,
        baseline: Double,
        ascent: Double,
        descent: Double
    ) {
        self.text = text
        self.range = range
        self.baseline = baseline
        self.ascent = ascent
        self.descent = descent
    }

    // MARK: - Public
    // MARK: - Private
}
