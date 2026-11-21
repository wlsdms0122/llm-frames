//
//  Homography+Carrying.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

extension Homography {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The corners of the part of the rectangle in front of the horizon, carried, and cut to `area`: a convex polygon,
    // empty when none of the rectangle lands in the area.
    package func corners(
        carrying rectangle: Rectangle,
        within area: Rectangle
    ) -> [Point] {
        let carried = ConvexPolygon(rectangle: rectangle)
            .carried(by: self)
            .clipped(to: ConvexPolygon(rectangle: area))

        return carried.isEmpty ? [] : carried.corners
    }

    // MARK: - Private
}
