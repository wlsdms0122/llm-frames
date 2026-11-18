//
//  ResolvedShape+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape clip's entry as resolve planned it, every static property one keyframe at the clip's instant. A shape placed
// by its area or its points takes them and its position as found, and its named anchor is that point of its
// geometry's box at the instant. A shape placed by its area or its points was checked to write them, so they were
// found.
extension ResolvedShape {
    // MARK: - Property
    // MARK: - Initializer
    init(
        shape: ShapeAppearance,
        geometry found: ClipGeometry,
        instant: Double
    ) {
        let position = found.position?.keyframes(at: instant) { $0 }
        let geometry: ShapeGeometry
        switch shape.geometry {
        case let .box(width, height, outset):
            geometry = .box(
                width: width.keyframes(at: instant) { $0 },
                height: height.keyframes(at: instant) { $0 },
                outset: outset
            )

        case let .area(outset, anchor):
            let area = found.area?.keyframes(at: instant) { $0.rectangle } ?? []
            geometry = .area(
                area,
                outset: outset,
                placement: GeometryPlacement(
                    position: position,
                    anchor: anchor.map { name in area.value(at: instant).point(named: name) }
                )
            )

        case let .points(isClosed, anchor):
            let points = found.points?.keyframes(at: instant) { $0 } ?? []
            geometry = .points(
                points,
                isClosed: isClosed,
                placement: GeometryPlacement(
                    position: position,
                    anchor: anchor.map { name in Rectangle(bounding: points.value(at: instant)).point(named: name) }
                )
            )
        }

        self.init(
            kind: shape.kind,
            geometry: geometry,
            radius: shape.radius.keyframes(at: instant) { $0 },
            trim: shape.trim.keyframes(at: instant) { $0 },
            fill: shape.fill,
            stroke: shape.stroke,
            shadow: shape.shadow
        )
    }

    // MARK: - Public
    // MARK: - Private
}
