//
//  CharacterScope.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Which characters of its title a glyphs item reports: every character, on the one item of a title not animated by
// unit, or those of the unit at its index, on a unit's `fills` item.
enum CharacterScope: Equatable, Sendable {
    case title
    case unit(Int)
}
