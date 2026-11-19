//
//  FontListOrigin.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Where a font list was written: the place and kind a stop on it names, and the pack it was written in, whose fonts it
// looks in before the machine's, nil outside every pack.
struct FontListOrigin: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let kind: String
    let pack: String?

    // MARK: - Initializer
    init(
        place: Place,
        kind: String,
        pack: String?
    ) {
        self.place = place
        self.kind = kind
        self.pack = pack
    }

    // MARK: - Public
    // MARK: - Private
}
