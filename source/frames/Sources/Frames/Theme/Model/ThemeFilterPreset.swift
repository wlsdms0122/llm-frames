//
//  ThemeFilterPreset.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A preset the theme's default filter names, with the place in the theme that names it, which a stop on its values
// names.
struct ThemeFilterPreset: Equatable, Sendable {
    // MARK: - Property
    let preset: FilterPreset
    let place: Place

    // MARK: - Initializer
    init(preset: FilterPreset, place: Place) {
        self.preset = preset
        self.place = place
    }

    // MARK: - Public
    // MARK: - Private
}
