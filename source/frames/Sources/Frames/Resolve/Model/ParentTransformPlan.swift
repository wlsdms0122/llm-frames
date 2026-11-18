//
//  ParentTransformPlan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape parent placed by its geometry as resolve plans its transform before its entry exists (FRAMES-10): its
// geometry as its entry holds it (`ShapeGeometry(plan:area:points:position:instant:track:)`), in its own parent's
// space, the track a tracked shape follows, and its scale and rotation, every keyframe in sequence time.
// `transform(at:)` is the map from the space its children are written in to that of its own parent, without its
// animation and its tracked motion, by the formula its evaluation lays it out with: a tracked shape's keyframes are
// brought back to the instant first, as evaluation brings them back. Its outset is how it is drawn and takes no part.
struct ParentTransformPlan: Equatable, Sendable {
    // MARK: - Property
    let geometry: ShapeGeometry
    let track: StorylineTrack?
    let scale: [Keyframe<Double>]
    let rotation: [Keyframe<Double>]

    // MARK: - Initializer
    init(
        geometry: ShapeGeometry,
        track: StorylineTrack?,
        scale: [Keyframe<Double>],
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
            position: placement?.position.map { position in (track?.position(position) ?? position).value(at: time) },
            scale: scale.value(at: time),
            rotation: rotation.value(at: time)
        )
    }

    // MARK: - Private
    private func bounds(at time: Double) -> Rectangle {
        switch geometry {
        case .box:
            geometry.bounds(at: time)

        case let .area(area, _, _):
            (track?.area(area) ?? area).value(at: time)

        case let .points(points, _, _):
            Rectangle(bounding: (track?.points(points) ?? points).value(at: time))
        }
    }
}
