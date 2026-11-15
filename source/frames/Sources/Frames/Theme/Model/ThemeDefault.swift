//
//  ThemeDefault.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A choice the theme gives a clip that names none, with its place in the theme and the kind of that place, so a stop
// it causes points at the theme.
struct ThemeDefault<Choice: Equatable & Sendable>: Equatable, Sendable {
    // MARK: - Property
    let choice: Choice
    let place: Place
    let kind: String

    // MARK: - Initializer
    init(
        choice: Choice,
        place: Place,
        kind: String
    ) {
        self.choice = choice
        self.place = place
        self.kind = kind
    }

    // MARK: - Public
    // MARK: - Private
}
