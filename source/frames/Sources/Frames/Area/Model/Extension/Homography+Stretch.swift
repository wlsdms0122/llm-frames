//
//  Homography+Stretch.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

import Foundation

extension Homography {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The largest factor by which the homography stretches a length at the point, in any direction: the larger singular
    // value of its derivative there. Nil where the point does not lie in front of the horizon.
    package func stretch(at point: Point) -> Double? {
        let w = self.w(at: point)
        guard let image = apply(to: point) else { return nil }

        let xByX = (a - g * image.x) / w
        let xByY = (c - h * image.x) / w
        let yByX = (b - g * image.y) / w
        let yByY = (d - h * image.y) / w
        let sum = xByX * xByX + xByY * xByY + yByX * yByX + yByY * yByY
        let determinant = xByX * yByY - xByY * yByX

        return ((sum + max(0, sum * sum - 4 * determinant * determinant).squareRoot()) / 2).squareRoot()
    }

    // MARK: - Private
}
