//
//  ParentTransformPlan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape parent placed by its geometry as resolve plans its transform before its entry exists (FRAMES-10): its area,
// already grown by its outset, or its points, and its position, in its own parent's space and where they lie at its
// instant, its anchor point when it names one, and its scale and rotation, every keyframe in sequence time.
// `transform(at:)` is the map from the space its children are written in to that of its own parent, without its
// animation and its tracked motion, as `ShapeEvaluator` lays the shape out.
struct ParentTransformPlan: Equatable, Sendable {
    // MARK: - Property
    let area: [Keyframe<Rectangle>]?
    let points: [Keyframe<[Point]>]?
    let position: [Keyframe<Point>]?
    let anchor: Point?
    let scale: [Keyframe<Double>]
    let rotation: [Keyframe<Double>]

    // MARK: - Initializer
    init(
        area: [Keyframe<Rectangle>]?,
        points: [Keyframe<[Point]>]?,
        position: [Keyframe<Point>]?,
        anchor: Point?,
        scale: [Keyframe<Double>],
        rotation: [Keyframe<Double>]
    ) {
        self.area = area
        self.points = points
        self.position = position
        self.anchor = anchor
        self.scale = scale
        self.rotation = rotation
    }

    // MARK: - Public
    // The shape turns and scales about its anchor point, the centre of its geometry's box at the time unless it names
    // one, and its position moves that point there.
    func transform(at time: Double) -> AffineTransform {
        let bounds = area.map { $0.value(at: time) }
            ?? points.map { Rectangle(bounding: $0.value(at: time)) }
            ?? Rectangle(x: 0, y: 0, width: 0, height: 0)
        let anchor = self.anchor ?? bounds.center
        let position = self.position.map { $0.value(at: time) } ?? anchor

        return AffineTransform(
            scale: scale.value(at: time),
            rotation: rotation.value(at: time),
            about: anchor,
            offset: Point(x: position.x - anchor.x, y: position.y - anchor.y)
        )
    }

    // MARK: - Private
}
