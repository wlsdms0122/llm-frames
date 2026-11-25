//
//  NullGeometry+Plan.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A null's geometry plan made its geometry and where it goes, every static property one keyframe at the clip's instant
// but a followed value true on the track's frame. Its anchor is named as a rect's is (`ShapeGeometry`), and a null
// placed by its area was checked to write it, so it was found.
extension NullGeometry {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: NullGeometryPlan,
        geometry found: ClipGeometry,
        instant: Double
    ) {
        switch plan {
        case let .box(width, height):
            self = .box(width: width.keyframes(at: instant) { $0 }, height: height.keyframes(at: instant) { $0 })

        case let .area(anchor):
            let area = found.area?.followed(at: instant, isOnTrackFrame: found.onTrackFrame.contains(.area)) { $0.geometry }
                ?? .keyframes([])
            let box = { (found.track?.area(area) ?? area).mapValues(\.fixed).value(at: instant) }
            let holdsClipArea = area.values.contains { $0.clipArea != nil }
            self = .area(
                area,
                placement: GeometryPlacement(
                    position: found.position?
                        .followed(at: instant, isOnTrackFrame: found.onTrackFrame.contains(.position)) { $0 },
                    anchor: anchor.map { ShapeGeometry.anchor(named: $0, holdsClipArea: holdsClipArea, in: box) }
                )
            )
        }
    }

    // MARK: - Public
    // MARK: - Private
}
