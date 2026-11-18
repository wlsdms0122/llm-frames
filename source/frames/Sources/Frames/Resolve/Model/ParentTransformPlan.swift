//
//  ParentTransformPlan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape parent placed by its geometry as resolve plans its transform before its entry exists (FRAMES-10): its
// geometry and where it goes, in its own parent's space and where they lie at its instant, and its scale and rotation,
// every keyframe in sequence time. `transform(at:)` is the map from the space its children are written in to that of
// its own parent, without its animation and its tracked motion, by the formula its evaluation lays it out with. Its
// outset is how it is drawn and takes no part.
struct ParentTransformPlan: Equatable, Sendable {
    // MARK: - Property
    let geometry: ShapeGeometry
    let scale: [Keyframe<Double>]
    let rotation: [Keyframe<Double>]

    // MARK: - Initializer
    init(
        geometry: ShapeGeometry,
        scale: [Keyframe<Double>],
        rotation: [Keyframe<Double>]
    ) {
        self.geometry = geometry
        self.scale = scale
        self.rotation = rotation
    }

    // MARK: - Public
    func transform(at time: Double) -> AffineTransform {
        let placement = geometry.placement
        return AffineTransform(
            placing: geometry.bounds(at: time),
            anchor: placement?.anchor,
            position: placement?.position.map { $0.value(at: time) },
            scale: scale.value(at: time),
            rotation: rotation.value(at: time)
        )
    }

    // MARK: - Private
}
