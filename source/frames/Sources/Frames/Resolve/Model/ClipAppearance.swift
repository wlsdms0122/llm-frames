//
//  ClipAppearance.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a connected or sequence clip is drawn. Keyframes are in sequence time, and `opacity`, `scale` and `rotation` are
// 1, 1 and 0 when not written. The lengths in `filter` are already scaled.
struct ClipAppearance: Equatable, Sendable {
    // MARK: - Property
    let opacity: PropertyValue<Double>
    let scale: PropertyValue<Double>
    let rotation: PropertyValue<Double>
    let blend: String
    let shape: ShapeAppearance?
    let filter: [FilterOperation]
    let media: MediaAppearance?

    // MARK: - Initializer
    init(
        opacity: PropertyValue<Double>,
        scale: PropertyValue<Double>,
        rotation: PropertyValue<Double>,
        blend: String,
        shape: ShapeAppearance?,
        filter: [FilterOperation],
        media: MediaAppearance?
    ) {
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.blend = blend
        self.shape = shape
        self.filter = filter
        self.media = media
    }

    // MARK: - Public
    // MARK: - Private
}
