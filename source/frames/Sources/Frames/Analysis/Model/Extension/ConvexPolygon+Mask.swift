//
//  ConvexPolygon+Mask.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The region of output pixels outside which an item's masks combine to 0, as far as one convex polygon can say. A
// geometry stands for the polygon that holds it: a rect or an ellipse its rectangle carried by its transform, so the
// curve of an ellipse and rounded corners are left out, and a path the convex hull of its carried vertices and their
// tangents' control points, which holds its curve, so a concave path covers its hull. Only an `add` or an `intersect`
// mask without feather and not inverted bounds the result: an `add` of any other mask reaches everywhere, since a
// feather's blur and an inverted outside have no edge, and a `subtract`, or an `intersect` with a feather or inverted,
// only lowers what is there, so the holes it cuts are left out.
extension ConvexPolygon {
    // MARK: - Property
    // MARK: - Initializer
    // Nil where no polygon bounds the masks: for an item without masks, or when they reach everywhere.
    init?(bounding masks: [ItemMask]) {
        guard let first = masks.first else { return nil }

        // A result that starts at 0 is 0 everywhere until a mask adds to it, and one that starts at 1 has no bound.
        var region: ConvexPolygon? = first.mode.startValue == 0 ? ConvexPolygon(corners: []) : nil
        for mask in masks {
            let isSharp = mask.feather == 0 && !mask.isInverted
            let shape = ConvexPolygon(geometry: mask.geometry, transform: mask.transform)

            switch mask.mode {
            case .add:
                // What covers nothing adds no corner of its own.
                let corners = { (polygon: ConvexPolygon) in polygon.isEmpty ? [] : polygon.corners }
                region = isSharp ? region.map { ConvexPolygon(hullOf: corners($0) + corners(shape)) } : nil

            case .subtract:
                break

            case .intersect:
                guard isSharp else { break }

                region = region.map { $0.clipped(to: shape) } ?? shape
            }
        }

        guard let region else { return nil }

        self = region
    }

    // MARK: - Public
    // MARK: - Private
    private init(
        geometry: PathGeometry,
        transform: AffineTransform
    ) {
        switch geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            self.init(rectangle: rectangle, transform: transform)

        case let .path(vertices, _):
            let carried = vertices.map { $0.carried(by: transform) }
            self.init(hullOf: carried.flatMap { vertex in
                [vertex.inTangent, Point(x: 0, y: 0), vertex.outTangent].map { tangent in
                    Point(x: vertex.vertex.x + tangent.x, y: vertex.vertex.y + tangent.y)
                }
            })
        }
    }
}
