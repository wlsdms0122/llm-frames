//
//  ResolvedShape+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape clip's entry as resolve planned it, every static property one keyframe at the clip's instant. A shape placed
// by its area or its points takes them as found, and its named anchor is that point of its geometry's box at the
// instant. A shape placed by its area or its points was checked to write them, so they were found.
extension ResolvedShape {
    // MARK: - Property
    // MARK: - Initializer
    init(
        shape: ShapeAppearance,
        geometry found: ClipGeometry,
        instant: Double
    ) {
        let geometry: ShapeGeometry = switch shape.geometry {
        case let .box(width, height, outset):
            .box(
                width: width.keyframes(at: instant) { $0 },
                height: height.keyframes(at: instant) { $0 },
                outset: outset
            )

        case let .area(outset):
            .area(found.area?.keyframes(at: instant) { $0.rectangle } ?? [], outset: outset)

        case let .points(isClosed):
            .points(found.points?.keyframes(at: instant) { $0 } ?? [], isClosed: isClosed)
        }
        let isPlacedByBox = if case .box = geometry { true } else { false }

        self.init(
            kind: shape.kind,
            geometry: geometry,
            radius: shape.radius.keyframes(at: instant) { $0 },
            trim: shape.trim.keyframes(at: instant) { $0 },
            fill: shape.fill,
            stroke: shape.stroke,
            shadow: shape.shadow,
            position: isPlacedByBox ? nil : found.position?.keyframes(at: instant) { $0 },
            anchor: isPlacedByBox ? nil : shape.anchor.map { name in
                NamedPoint(area: geometry.bounds(at: instant), name: name)
            }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
