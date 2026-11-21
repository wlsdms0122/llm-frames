//
//  EvaluationWord.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// One word of a title `evaluate` reports: its text and its `[start, end)` in Unicode scalars over its title's text. A
// word has no place of its own: it lies where the characters inside its range lie.
package struct EvaluationWord: Equatable, Sendable {
    // MARK: - Property
    package let text: String
    package let range: Range<Int>

    // MARK: - Initializer
    init(
        text: String,
        range: Range<Int>
    ) {
        self.text = text
        self.range = range
    }

    // MARK: - Public
    // MARK: - Private
}
