//
//  ItemCoverage.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What a display item covers of the output, in output pixels: its pieces, less its holes. Both are carried by every
// transform that holds the item, but only a piece is cut by its masks, reveals and pictures, since a hole matters only
// for a point already in a piece.
struct ItemCoverage: Equatable, Sendable {
    // MARK: - Property
    let pieces: [ConvexPolygon]
    let holes: [ConvexPolygon]

    // The axis-aligned box of every piece that a hole does not swallow whole, nil when it covers nothing. A convex
    // hole holding every corner of a convex piece holds all of it.
    var bounds: Rectangle? {
        let boxes = pieces
            .filter { piece in !holes.contains { hole in piece.corners.allSatisfy(hole.contains) } }
            .compactMap(\.bounds)
        guard let first = boxes.first else { return nil }

        let left = boxes.map(\.x).min() ?? first.x
        let top = boxes.map(\.y).min() ?? first.y
        let right = boxes.map { $0.x + $0.width }.max() ?? first.x + first.width
        let bottom = boxes.map { $0.y + $0.height }.max() ?? first.y + first.height

        return Rectangle(x: left, y: top, width: right - left, height: bottom - top)
    }

    // MARK: - Initializer
    init(
        pieces: [ConvexPolygon],
        holes: [ConvexPolygon] = []
    ) {
        self.pieces = pieces
        self.holes = holes
    }

    // MARK: - Public
    func applying(_ transform: AffineTransform) -> ItemCoverage {
        ItemCoverage(pieces: pieces.map { $0.applying(transform) }, holes: holes.map { $0.applying(transform) })
    }

    func clipped(to polygon: ConvexPolygon) -> ItemCoverage {
        ItemCoverage(pieces: pieces.map { $0.clipped(to: polygon) }.filter { !$0.isEmpty }, holes: holes)
    }

    // Whether the point lies in a piece and in no hole, so a point on a hole's edge is not covered.
    func contains(_ point: Point) -> Bool {
        pieces.contains { $0.contains(point) } && !holes.contains { $0.contains(point) }
    }

    // MARK: - Private
}
