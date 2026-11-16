//
//  ClipAppearance.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a connected or sequence clip is drawn, with every value resolve leaves for evaluation: `opacity`, `scale` and
// `rotation` with keyframes in sequence time, 1, 1 and 0 when not written, its blend mode, a shape's colour, and the
// filter operations it applies, its lengths already scaled, and how a media clip's picture fills its box.
struct ClipAppearance: Equatable, Sendable {
    // MARK: - Property
    let opacity: PropertyValue<Double>
    let scale: PropertyValue<Double>
    let rotation: PropertyValue<Double>
    let blend: String
    let color: Color?
    let filter: [FilterOperation]
    let media: MediaAppearance?

    // MARK: - Initializer
    init(
        opacity: PropertyValue<Double>,
        scale: PropertyValue<Double>,
        rotation: PropertyValue<Double>,
        blend: String,
        color: Color?,
        filter: [FilterOperation],
        media: MediaAppearance?
    ) {
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.blend = blend
        self.color = color
        self.filter = filter
        self.media = media
    }

    // MARK: - Public
    // MARK: - Private
}
