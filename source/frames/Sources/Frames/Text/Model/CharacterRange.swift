//
//  CharacterRange.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Characters of one line: `count` of its clusters from the one at `first`, the line its index among the text's lines.
struct CharacterRange: Equatable, Sendable {
    // MARK: - Property
    let line: Int
    let first: Int
    let count: Int

    // MARK: - Initializer
    init(
        line: Int,
        first: Int,
        count: Int
    ) {
        self.line = line
        self.first = first
        self.count = count
    }

    // MARK: - Public
    // MARK: - Private
}
