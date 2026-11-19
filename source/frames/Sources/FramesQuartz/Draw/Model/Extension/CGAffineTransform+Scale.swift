//
//  CGAffineTransform+Scale.swift
//  FramesQuartz
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Foundation

extension CGAffineTransform {
    // MARK: - Property
    // How long a unit along the x axis and along the y axis comes out.
    var axisScale: CGSize {
        CGSize(width: hypot(a, b), height: hypot(c, d))
    }

    // How long a length that has no direction (a blur radius, a feather) comes out: the square root of the area scale.
    var lengthScale: CGFloat {
        abs(a * d - b * c).squareRoot()
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
