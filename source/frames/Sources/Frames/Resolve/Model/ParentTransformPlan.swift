//
//  ParentTransformPlan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape parent placed by its geometry as resolve plans its transform before its entry exists (FRAMES-10): its area
// or its points, its outset, and its position, in its own parent's space and where they lie at its instant, its anchor
// point when it names one, and its scale and rotation, every keyframe in sequence time. `transform(at:)` is the map
// from the space its children are written in to that of its own parent, without its animation and its tracked motion,
// by the formula its evaluation lays it out with. Its outset is taken as it is in its parent's space, since the scale
// of that space on the frame is only known when it is evaluated.
struct ParentTransformPlan: Equatable, Sendable {
    // MARK: - Property
    let geometry: ShapeGeometry
    let position: [Keyframe<Point>]?
    let anchor: NamedPoint?
    let scale: [Keyframe<Double>]
    let rotation: [Keyframe<Double>]

    // MARK: - Initializer
    init(
        geometry: ShapeGeometry,
        position: [Keyframe<Point>]?,
        anchor: NamedPoint?,
        scale: [Keyframe<Double>],
        rotation: [Keyframe<Double>]
    ) {
        self.geometry = geometry
        self.position = position
        self.anchor = anchor
        self.scale = scale
        self.rotation = rotation
    }

    // MARK: - Public
    func transform(at time: Double) -> AffineTransform {
        AffineTransform(
            placing: geometry.bounds(at: time),
            outset: geometry.outset,
            anchor: anchor,
            position: position.map { $0.value(at: time) },
            scale: scale.value(at: time),
            rotation: rotation.value(at: time)
        )
    }

    // MARK: - Private
}
