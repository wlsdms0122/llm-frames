//
//  PathVertex.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// A path's vertex (FRAMES-11 Paths): its point and its in and out tangents, offsets from the point in the space the
// point is in. The segment from one vertex to the next is the cubic Bézier curve whose control points are the first's
// point plus its out tangent and the next's point plus its in tangent. Each stage of resolve and evaluation holds the
// three in its own form: as written, as found, timed or sampled.
package struct PathVertex<Location: Equatable & Sendable, Offset: Equatable & Sendable>: Equatable, Sendable {
    // MARK: - Property
    package let vertex: Location
    package let inTangent: Offset
    package let outTangent: Offset

    // MARK: - Initializer
    package init(
        vertex: Location,
        inTangent: Offset,
        outTangent: Offset
    ) {
        self.vertex = vertex
        self.inTangent = inTangent
        self.outTangent = outTangent
    }

    // MARK: - Public
    func map<OtherLocation, OtherOffset>(
        vertex transformVertex: (Location) throws -> OtherLocation,
        tangent transformTangent: (Offset) throws -> OtherOffset
    ) rethrows -> PathVertex<OtherLocation, OtherOffset> {
        PathVertex<OtherLocation, OtherOffset>(
            vertex: try transformVertex(vertex),
            inTangent: try transformTangent(inTangent),
            outTangent: try transformTangent(outTangent)
        )
    }

    // MARK: - Private
}
