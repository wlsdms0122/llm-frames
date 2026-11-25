//
//  StorylineAppearance.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a storyline clip's picture is drawn inside its storyline picture. `box` is the frame its conformed crop fills,
// placed by its position and anchor, and `cornerPin` that box placed by its corner pin instead, nil for a clip without
// one (FRAMES-27). Keyframes are in sequence time, and `opacity`, `scale` and `rotation` are 1, 1
// and 0 when not written. `blend` is the blend mode its storyline picture takes over what lies below, and `radius`,
// `border` and `shadow` are timed values in output pixels, `off` for none. A solid keeps the plain values and has no
// box, since it fills the frame.
struct StorylineAppearance: Equatable, Sendable {
    // MARK: - Property
    let box: ClipBox?
    let cornerPin: ClipCornerPin?
    let opacity: PropertyValue<Double>
    let scale: PropertyValue<Scale>
    let rotation: PropertyValue<Double>
    let blend: String
    let radius: TimedValue
    let border: TimedValue
    let shadow: TimedValue

    // MARK: - Initializer
    init(
        box: ClipBox?,
        cornerPin: ClipCornerPin?,
        opacity: PropertyValue<Double>,
        scale: PropertyValue<Scale>,
        rotation: PropertyValue<Double>,
        blend: String,
        radius: TimedValue,
        border: TimedValue,
        shadow: TimedValue
    ) {
        self.box = box
        self.cornerPin = cornerPin
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.blend = blend
        self.radius = radius
        self.border = border
        self.shadow = shadow
    }

    // MARK: - Public
    // The same appearance placed by `box` and `cornerPin`.
    func with(
        box: ClipBox?,
        cornerPin: ClipCornerPin?
    ) -> StorylineAppearance {
        StorylineAppearance(
            box: box,
            cornerPin: cornerPin,
            opacity: opacity,
            scale: scale,
            rotation: rotation,
            blend: blend,
            radius: radius,
            border: border,
            shadow: shadow
        )
    }

    // MARK: - Private
}
