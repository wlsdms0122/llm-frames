//
//  ItemPresentation.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where and how opaque a clip's item is drawn once its keyframes and animation combine: scale and opacity multiply,
// rotation and the offset add, and the offset `x`, `y` is in multiples of the clip's own size, its box before any
// scale. Scale and rotation act about one point, so a preset looks the same about any anchor point.
struct ItemPresentation: Equatable, Sendable {
    // MARK: - Property
    let transform: AffineTransform
    let opacity: Double

    // MARK: - Initializer
    // A clip with a box, its item drawn in the box's own pixels: the box's top left goes to the keyframed position,
    // and scale and rotation act about `anchor`, a point in the box's own pixels.
    init(
        box size: Size,
        anchor: Point,
        values: KeyframedValues,
        motion: Motion
    ) {
        let offset = Point(
            x: values.position.x + motion.value(of: .x) * size.width,
            y: values.position.y + motion.value(of: .y) * size.height
        )

        self.transform = AffineTransform(scale: values.scale.multiplied(by: motion.value(of: .scale)), about: anchor)
            .concatenating(AffineTransform(rotation: values.rotation + motion.value(of: .rotation), about: anchor))
            .concatenating(AffineTransform(translation: offset))
        self.opacity = values.opacity * motion.value(of: .opacity)
    }

    // A clip placed by an area, its item drawn in the coordinates the area is written in: scale and rotation act about
    // the centre of `area`, the clip's own box, and the offset is in multiples of its size. `parent` then carries those
    // coordinates to output pixels.
    init(
        area: Rectangle,
        opacity: Double,
        motion: Motion,
        carriedBy parent: AffineTransform = .identity
    ) {
        let offset = Point(x: motion.value(of: .x) * area.width, y: motion.value(of: .y) * area.height)

        self.transform = AffineTransform(scale: motion.value(of: .scale), about: area.center)
            .concatenating(AffineTransform(rotation: motion.value(of: .rotation), about: area.center))
            .concatenating(AffineTransform(translation: offset))
            .concatenating(parent)
        self.opacity = opacity * motion.value(of: .opacity)
    }

    // MARK: - Public
    // MARK: - Private
}
