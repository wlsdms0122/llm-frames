//
//  TextUnit.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// What a title animated by unit moves one at a time: an extended grapheme cluster, a word or a laid out line.
enum TextUnit: String, CaseIterable, Equatable, Sendable {
    case character
    case word
    case line

    // MARK: - Property
    // The seconds between units when the choice writes no `stagger`.
    var defaultStagger: Double {
        switch self {
        case .character:
            0.04

        case .word:
            0.12

        case .line:
            0.3
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
