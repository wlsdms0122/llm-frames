//
//  GeometryQuad.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// A corner pin as evaluation takes it (FRAMES-27): the points the top left, top right, bottom right and bottom left
// corners of a clip's box go to, each a point or the point a placement name gives of a clip area.
struct GeometryQuad: Equatable, Sendable {
    // MARK: - Property
    let topLeft: GeometryPoint
    let topRight: GeometryPoint
    let bottomRight: GeometryPoint
    let bottomLeft: GeometryPoint

    var corners: [GeometryPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }

    // The quad of its points, nil where one of them is a point of a clip area, the named clip's box known only when
    // evaluated.
    var fixed: Quad? {
        guard corners.allSatisfy({ $0.clipArea == nil }) else { return nil }

        return sampled { $0.fixed }
    }

    // MARK: - Initializer
    init(
        topLeft: GeometryPoint,
        topRight: GeometryPoint,
        bottomRight: GeometryPoint,
        bottomLeft: GeometryPoint
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    init(_ quad: Quad) {
        self.init(
            topLeft: .point(quad.topLeft),
            topRight: .point(quad.topRight),
            bottomRight: .point(quad.bottomRight),
            bottomLeft: .point(quad.bottomLeft)
        )
    }

    // The four points of a corner pin as found, in their order, which the key table has checked are four.
    init(corners: [GeometryPoint]) {
        self.init(topLeft: corners[0], topRight: corners[1], bottomRight: corners[2], bottomLeft: corners[3])
    }

    // MARK: - Public
    func map(_ transform: (Point) throws -> Point) rethrows -> GeometryQuad {
        GeometryQuad(
            topLeft: try topLeft.map(transform),
            topRight: try topRight.map(transform),
            bottomRight: try bottomRight.map(transform),
            bottomLeft: try bottomLeft.map(transform)
        )
    }

    func sampled(_ point: (GeometryPoint) throws -> Point) rethrows -> Quad {
        Quad(
            topLeft: try point(topLeft),
            topRight: try point(topRight),
            bottomRight: try point(bottomRight),
            bottomLeft: try point(bottomLeft)
        )
    }

    // MARK: - Private
}
