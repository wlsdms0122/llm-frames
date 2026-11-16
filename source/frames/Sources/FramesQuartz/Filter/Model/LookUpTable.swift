//
//  LookUpTable.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreImage
import Foundation
import Frames

// A 3D LUT as the `filterLookUp` kernel samples it: `image` holds entry (red, green, blue) at the texel centre of
// column red, row green + blue × `size`, counted from the bottom, with no colour space, so its values reach the
// kernel as written.
struct LookUpTable: Sendable {
    // MARK: - Property
    let size: Int
    let domainMin: CIVector
    let domainMax: CIVector
    let image: CIImage

    // MARK: - Initializer
    init(cube: CubeLUT) {
        let size = cube.size
        let rows = size * size
        var texels = [Float](repeating: 1, count: rows * size * 4)
        for row in 0..<rows {
            // Core Image puts the first row of bitmap data at the top.
            let memoryRow = rows - 1 - row
            for column in 0..<size {
                let entry = (row * size + column) * 3
                let texel = (memoryRow * size + column) * 4
                texels[texel] = Float(cube.values[entry])
                texels[texel + 1] = Float(cube.values[entry + 1])
                texels[texel + 2] = Float(cube.values[entry + 2])
            }
        }

        self.size = size
        self.domainMin = CIVector(x: cube.domainMin[0], y: cube.domainMin[1], z: cube.domainMin[2])
        self.domainMax = CIVector(x: cube.domainMax[0], y: cube.domainMax[1], z: cube.domainMax[2])
        self.image = CIImage(
            bitmapData: texels.withUnsafeBufferPointer { Data(buffer: $0) },
            bytesPerRow: size * 16,
            size: CGSize(width: size, height: rows),
            format: .RGBAf,
            colorSpace: nil
        )
    }

    // MARK: - Public
    // MARK: - Private
}
