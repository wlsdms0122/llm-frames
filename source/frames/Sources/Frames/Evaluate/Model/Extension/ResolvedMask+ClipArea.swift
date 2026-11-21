//
//  ResolvedMask+ClipArea.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A mask whose area, box position or points hold a clip area takes it at an instant: each such keyframe is the named
// clip's box at that instant, as a clip's own area and points take it, so a span next to one moves with it.
extension ResolvedMask {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func taking(
        _ areas: ClipAreaSampler,
        at time: Double
    ) -> ResolvedMask {
        let area = { (area: GeometryArea) in GeometryArea.rectangle(areas.rectangle(of: area, at: time)) }
        let point = { (point: GeometryPoint) in GeometryPoint.point(areas.point(of: point, at: time)) }
        let rectangle = { (rectangle: ResolvedMaskRectangle) -> ResolvedMaskRectangle in
            switch rectangle {
            case let .area(keyframes):
                .area(keyframes.mapValues(area))

            case let .box(width, height, position):
                .box(width: width, height: height, position: position.mapValues(point))
            }
        }

        let geometry: ResolvedMaskGeometry = switch self.geometry {
        case let .rect(box, radius):
            .rect(rectangle(box), radius: radius)

        case let .ellipse(box):
            .ellipse(rectangle(box))

        case let .polyline(points):
            .polyline(points.map { $0.mapValues(point) })
        }

        return ResolvedMask(geometry: geometry, feather: feather, isInverted: isInverted, mode: mode)
    }

    // MARK: - Private
}
