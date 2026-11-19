//
//  ClipArea.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The box of the clip whose `id` is `clip`, at the instant being evaluated, in the space of the clip that writes it,
// grown by `padding` on every side. `padding` is in output pixels, its theme length times the length scale.
struct ClipArea: Equatable, Sendable {
    // MARK: - Property
    let clip: String
    let padding: Double

    // MARK: - Initializer
    init(
        clip: String,
        padding: Double
    ) {
        self.clip = clip
        self.padding = padding
    }

    // MARK: - Public
    // MARK: - Private
}
