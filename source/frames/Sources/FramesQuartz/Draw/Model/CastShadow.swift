//
//  CastShadow.swift
//  FramesQuartz
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Foundation
import Frames

// A drop shadow as it is cast in a raster's pixels. The shadow's radius and offset are in its item's own coordinates,
// so the matrix that carries them into the raster carries the offset and scales the radius by its area's square
// root.
struct CastShadow {
    // MARK: - Property
    let color: Color
    let blur: CGFloat
    let offset: CGSize

    // How far past the frame the shadow can be cast from: three standard deviations of its blur and its offset.
    var margin: Int {
        Int((3 * blur + hypot(offset.width, offset.height)).rounded(.up)) + 1
    }

    // MARK: - Initializer
    init(
        _ shadow: DropShadow,
        through matrix: CGAffineTransform
    ) {
        self.color = shadow.color
        self.blur = shadow.radius * matrix.lengthScale
        self.offset = CGSize(width: shadow.offset.x, height: shadow.offset.y).applying(matrix)
    }

    // MARK: - Public
    // MARK: - Private
}
