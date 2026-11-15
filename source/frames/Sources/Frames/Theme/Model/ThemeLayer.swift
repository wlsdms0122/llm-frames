//
//  ThemeLayer.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// One theme to merge, with the place its keys are written at: a theme file, a document's `theme`, or a clip. `pack`
// is the pack it is written in, whose fonts its `font` list looks for first.
struct ThemeLayer: Equatable, Sendable {
    // MARK: - Property
    let value: JSONValue
    let place: Place
    let pack: String?

    // MARK: - Initializer
    init(
        value: JSONValue,
        place: Place,
        pack: String? = nil
    ) {
        self.value = value
        self.place = place
        self.pack = pack
    }

    // MARK: - Public
    // MARK: - Private
}
