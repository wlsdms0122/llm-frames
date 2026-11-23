//
//  PathVertex+Interpolable.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// A vertex interpolates its point and its tangents each on its own, as keyframes time them apart (FRAMES-4).
extension PathVertex: Interpolable where Location: Interpolable, Offset: Interpolable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    static func interpolate(
        from start: PathVertex,
        to end: PathVertex,
        progress: Double
    ) -> PathVertex {
        PathVertex(
            vertex: .interpolate(from: start.vertex, to: end.vertex, progress: progress),
            inTangent: .interpolate(from: start.inTangent, to: end.inTangent, progress: progress),
            outTangent: .interpolate(from: start.outTangent, to: end.outTangent, progress: progress)
        )
    }

    // MARK: - Private
}
