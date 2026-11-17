//
//  StorylineAppearance.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a storyline clip's picture is drawn inside its storyline picture: `box`, the frame its conformed crop fills,
// placed by its position and anchor; `opacity`, `scale` and `rotation` with keyframes in sequence time, 1, 1 and 0
// when not written; the blend mode its storyline picture takes over what lies below; and the radius of the box's
// corners in output pixels, its border and its shadow. A solid takes none of these and keeps their plain values, and
// has no box of its own, since it fills the frame.
struct StorylineAppearance: Equatable, Sendable {
    // MARK: - Property
    let box: ClipBox?
    let opacity: PropertyValue<Double>
    let scale: PropertyValue<Double>
    let rotation: PropertyValue<Double>
    let blend: String
    let radius: Double
    let border: MediaBorder?
    let shadow: MediaShadow?

    // MARK: - Initializer
    init(
        box: ClipBox?,
        opacity: PropertyValue<Double>,
        scale: PropertyValue<Double>,
        rotation: PropertyValue<Double>,
        blend: String,
        radius: Double,
        border: MediaBorder?,
        shadow: MediaShadow?
    ) {
        self.box = box
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.blend = blend
        self.radius = radius
        self.border = border
        self.shadow = shadow
    }

    // MARK: - Public
    // MARK: - Private
}
