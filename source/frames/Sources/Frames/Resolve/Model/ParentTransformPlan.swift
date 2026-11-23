//
//  ParentTransformPlan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape parent placed by its geometry, as resolve plans its transform before its entry exists. `geometry` is as its
// entry holds it, in its own parent's space, and every keyframe is in sequence time. `transform(at:)` maps the space
// its children are written in to that of its own parent, without its animation and its tracked motion, and must lay
// the shape out as evaluation does: a tracked shape's keyframes are brought back to the instant first. Its outset
// takes no part. ParentSpacePlanner takes no transform of a shape whose geometry or position holds a clip area, which
// only evaluation knows the box of.
struct ParentTransformPlan: Equatable, Sendable {
    // MARK: - Property
    let geometry: ShapeGeometry
    let track: TrackedMedia?
    let scale: [Keyframe<Scale>]
    let rotation: [Keyframe<Double>]

    // MARK: - Initializer
    init(
        geometry: ShapeGeometry,
        track: TrackedMedia?,
        scale: [Keyframe<Scale>],
        rotation: [Keyframe<Double>]
    ) {
        self.geometry = geometry
        self.track = track
        self.scale = scale
        self.rotation = rotation
    }

    // MARK: - Public
    func transform(at time: Double) -> AffineTransform {
        let placement = geometry.placement
        return AffineTransform(
            placing: bounds(at: time),
            anchor: placement?.anchor,
            position: placement?.position.map { position in
                (track?.position(position) ?? position).mapValues(\.fixed).value(at: time)
            },
            scale: scale.value(at: time),
            rotation: rotation.value(at: time)
        )
    }

    // MARK: - Private
    private func bounds(at time: Double) -> Rectangle {
        switch geometry {
        case let .box(width, height, _):
            Rectangle(x: 0, y: 0, width: width.value(at: time), height: height.value(at: time))

        case let .area(area, _, _):
            (track?.area(area) ?? area).mapValues(\.fixed).value(at: time)

        case let .points(points, isClosed, _):
            ShapeGeometry.bounds(of: track?.vertices(points) ?? points, isClosed: isClosed, at: time)
        }
    }
}
