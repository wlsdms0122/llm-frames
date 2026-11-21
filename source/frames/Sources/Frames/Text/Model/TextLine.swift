//
//  TextLine.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A line as broken: its characters in order, the spaces that hang at its end included, and its range of the title's
// text. `width` leaves out the spaces that hang at the line's end, and `ascent` and `descent` are the largest among
// its runs.
struct TextLine: Equatable, Sendable {
    // MARK: - Property
    let characters: [StyledCharacter]
    let range: Range<Int>
    let width: Double
    let ascent: Double
    let descent: Double

    // MARK: - Initializer
    init(
        characters: [StyledCharacter],
        range: Range<Int>,
        width: Double,
        ascent: Double,
        descent: Double
    ) {
        self.characters = characters
        self.range = range
        self.width = width
        self.ascent = ascent
        self.descent = descent
    }

    // MARK: - Public
    // MARK: - Private
}
