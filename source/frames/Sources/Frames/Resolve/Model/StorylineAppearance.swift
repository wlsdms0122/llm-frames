//
//  StorylineAppearance.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a storyline clip's picture is drawn inside its storyline picture. `box` is the frame its conformed crop fills,
// placed by its position and anchor. Keyframes are in sequence time, and `opacity`, `scale` and `rotation` are 1, 1
// and 0 when not written. `blend` is the blend mode its storyline picture takes over what lies below, and `radius`,
// `border` and `shadow` are timed values in output pixels, `off` for none. A solid keeps the plain values and has no box, since it fills the frame.
struct StorylineAppearance: Equatable, Sendable {
    // MARK: - Property
    let box: ClipBox?
    let opacity: PropertyValue<Double>
    let scale: PropertyValue<Double>
    let rotation: PropertyValue<Double>
    let blend: String
    let radius: TimedValue
    let border: TimedValue
    let shadow: TimedValue

    // MARK: - Initializer
    init(
        box: ClipBox?,
        opacity: PropertyValue<Double>,
        scale: PropertyValue<Double>,
        rotation: PropertyValue<Double>,
        blend: String,
        radius: TimedValue,
        border: TimedValue,
        shadow: TimedValue
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
