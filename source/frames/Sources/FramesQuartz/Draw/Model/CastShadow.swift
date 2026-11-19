//
//  CastShadow.swift
//  FramesQuartz
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Foundation
import Frames

// A drop shadow as it is cast in a raster's pixels. Its offset is in its item's own coordinates, carried into the
// raster by the item's matrix, and its radius in output pixels, scaled onto the raster by `rasterScale`.
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
        through matrix: CGAffineTransform,
        rasterScale: CGFloat
    ) {
        self.color = shadow.color
        self.blur = shadow.radius * rasterScale
        self.offset = CGSize(width: shadow.offset.x, height: shadow.offset.y).applying(matrix)
    }

    // MARK: - Public
    // MARK: - Private
}
