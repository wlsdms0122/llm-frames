//
//  Quad+Affine.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A quadrilateral carried corner by corner by an affine map, which keeps it a quadrilateral.
extension Quad {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func carried(by transform: AffineTransform) -> Quad {
        Quad(
            topLeft: transform.apply(to: topLeft),
            topRight: transform.apply(to: topRight),
            bottomRight: transform.apply(to: bottomRight),
            bottomLeft: transform.apply(to: bottomLeft)
        )
    }

    // MARK: - Private
}
