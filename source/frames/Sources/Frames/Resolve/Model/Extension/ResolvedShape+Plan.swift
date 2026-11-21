//
//  ResolvedShape+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape clip's entry as resolve planned it, every static property one keyframe at the clip's instant but a followed
// value true on the track's frame, its geometry made from its plan and its area or points and position as found, in
// the coordinates it is written in.
extension ResolvedShape {
    // MARK: - Property
    // MARK: - Initializer
    init(
        shape: ShapeAppearance,
        geometry found: ClipGeometry,
        instant: Double
    ) {
        self.init(
            kind: shape.kind,
            geometry: ShapeGeometry(
                plan: shape.geometry,
                area: found.area?.followed(at: instant, isOnTrackFrame: found.onTrackFrame.contains(.area)) { $0.geometry },
                points: found.points?.followed(at: instant, isOnTrackFrame: found.onTrackFrame.contains(.points)) { $0 },
                position: found.position?
                    .followed(at: instant, isOnTrackFrame: found.onTrackFrame.contains(.position)) { $0 },
                instant: instant,
                track: found.track
            ),
            radius: shape.radius,
            trim: shape.trim.keyframes(at: instant) { $0 },
            fill: shape.fill,
            stroke: shape.stroke,
            shadow: shape.shadow
        )
    }

    // MARK: - Public
    // MARK: - Private
}
