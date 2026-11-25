//
//  CornerPinPlane.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A clip's box B laid onto its corner pin Q by H(B → Q) (FRAMES-27). Where Q lays no plane, B having no area, Q not
// being strictly convex or a point of B carried behind the horizon, whatever lies on B lies on Q itself (FRAMES-23).
struct CornerPinPlane: Sendable {
    // MARK: - Property
    private let cornerPin: Quad
    private let homography: Homography?

    // MARK: - Initializer
    init(
        box: Rectangle,
        cornerPin: Quad
    ) {
        self.cornerPin = cornerPin
        self.homography = Homography(from: Quad(box), to: cornerPin)
    }

    // MARK: - Public
    // The quad carried into B by the transform, and then onto Q.
    func carry(
        _ quad: Quad,
        by transform: AffineTransform
    ) -> Quad {
        homography?.apply(to: quad.carried(by: transform)) ?? cornerPin
    }

    // MARK: - Private
}
