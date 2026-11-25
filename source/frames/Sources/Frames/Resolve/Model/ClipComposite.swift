//
//  ClipComposite.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How a connected or sequence clip's picture composites onto what is below it: its `opacity`, 1 when not written,
// keyframes in sequence time, and its `blend`, `normal` when not written.
struct ClipComposite: Equatable, Sendable {
    // MARK: - Property
    let opacity: PropertyValue<Double>
    let blend: String

    // MARK: - Initializer
    init(
        opacity: PropertyValue<Double>,
        blend: String
    ) {
        self.opacity = opacity
        self.blend = blend
    }

    // MARK: - Public
    // MARK: - Private
}
