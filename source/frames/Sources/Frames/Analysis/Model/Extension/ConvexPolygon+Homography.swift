//
//  ConvexPolygon+Homography.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A convex polygon carried by a homography: cut to the part in front of its horizon, then each corner carried. A
// homography takes a line in front of its horizon to a line, so the part carried stays convex. Nothing at or beyond the
// horizon is carried (FRAMES-27). The cut keeps w at or above a millionth of its largest value over the corners, so no
// corner goes to infinity; what the cut leaves out lies a million times farther out than the rest, past any frame.
extension ConvexPolygon {
    // MARK: - Property
    private static let horizonMargin = 1e-6

    // MARK: - Initializer
    // MARK: - Public
    func carried(by homography: Homography) -> ConvexPolygon {
        let ws = corners.map(homography.w(at:))
        guard let largest = ws.max(), largest > 0 else { return ConvexPolygon(corners: []) }

        let least = largest * Self.horizonMargin
        // w is linear in the point, so the edge crosses the cut where it interpolates to `least`.
        let front = corners.indices.flatMap { index -> [Point] in
            let next = (index + 1) % corners.count
            let side = ws[index] - least
            let nextSide = ws[next] - least
            let kept = side >= 0 ? [corners[index]] : []
            guard (side >= 0) != (nextSide >= 0) else { return kept }

            let progress = side / (side - nextSide)
            return kept + [Point.interpolate(from: corners[index], to: corners[next], progress: progress)]
        }

        return ConvexPolygon(corners: front.compactMap(homography.apply(to:)))
    }

    // MARK: - Private
}
