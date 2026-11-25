//
//  ClipAppearance.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a connected or sequence clip is drawn and moved. Keyframes are in sequence time, and `scale` and `rotation` are 1
// and 0 when not written. `drawing` is how its picture composites, or a null's geometry. `filter` is timed, `off` for
// none, its lengths in output pixels.
struct ClipAppearance: Equatable, Sendable {
    // MARK: - Property
    let drawing: ClipDrawing
    let scale: PropertyValue<Scale>
    let rotation: PropertyValue<Double>
    let shape: ShapeAppearance?
    let filter: TimedValue
    let media: MediaAppearance?

    // MARK: - Initializer
    init(
        drawing: ClipDrawing,
        scale: PropertyValue<Scale>,
        rotation: PropertyValue<Double>,
        shape: ShapeAppearance?,
        filter: TimedValue,
        media: MediaAppearance?
    ) {
        self.drawing = drawing
        self.scale = scale
        self.rotation = rotation
        self.shape = shape
        self.filter = filter
        self.media = media
    }

    // MARK: - Public
    // MARK: - Private
}
