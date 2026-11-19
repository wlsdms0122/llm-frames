//
//  ClipAreaReference.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A clip area as written: the `id` it names and the place of the area that names it.
struct ClipAreaReference: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let clip: String

    // MARK: - Initializer
    init(
        place: Place,
        clip: String
    ) {
        self.place = place
        self.clip = clip
    }

    // MARK: - Public
    // MARK: - Private
}
