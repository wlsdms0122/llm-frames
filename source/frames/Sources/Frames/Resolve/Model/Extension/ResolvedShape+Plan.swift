//
//  ResolvedShape+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape clip's entry as resolve planned it, every static property one keyframe at the clip's instant. An area is
// grown by the outset here, in the clip's coordinates, and a named anchor is taken on the geometry's box there at the
// instant.
extension ResolvedShape {
    // MARK: - Property
    // MARK: - Initializer
    init(
        shape: ShapeAppearance,
        geometry: ClipGeometry,
        instant: Double
    ) {
        let isPlacedByBox = geometry.box != nil
        let area = geometry.area?.keyframes(at: instant) { $0.rectangle.grown(by: shape.outset) }
        let points = geometry.points?.keyframes(at: instant) { $0 }
        let box = area.map { $0.value(at: instant) } ?? points.map { Rectangle(bounding: $0.value(at: instant)) }

        self.init(
            kind: shape.kind,
            area: area,
            width: shape.width?.keyframes(at: instant) { $0 },
            height: shape.height?.keyframes(at: instant) { $0 },
            points: points,
            isClosed: shape.kind == .path ? shape.isClosed : nil,
            radius: shape.radius.keyframes(at: instant) { $0 },
            trim: shape.trim.keyframes(at: instant) { $0 },
            fill: shape.fill,
            stroke: shape.stroke,
            shadow: shape.shadow,
            position: isPlacedByBox ? nil : geometry.position?.keyframes(at: instant) { $0 },
            anchor: isPlacedByBox ? nil : shape.anchor.flatMap { name in box?.point(named: name) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
