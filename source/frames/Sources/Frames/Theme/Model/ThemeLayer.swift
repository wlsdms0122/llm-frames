//
//  ThemeLayer.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// One theme to merge, with the place its keys are written at: a theme file, a document's `theme`, or a clip.
struct ThemeLayer: Equatable, Sendable {
    // MARK: - Property
    let value: JSONValue
    let place: Place

    // MARK: - Initializer
    init(
        value: JSONValue,
        place: Place
    ) {
        self.value = value
        self.place = place
    }

    // MARK: - Public
    // MARK: - Private
}
