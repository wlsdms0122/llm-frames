//
//  GreyTexture.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/22/26.
//

import Foundation

// A grey picture a plane is drawn with, values from 0 to 1 row by row from the top left.
package struct GreyTexture: Sendable {
    // MARK: - Property
    package let width: Int
    package let height: Int
    package let values: [Float]

    // MARK: - Initializer
    package init(
        width: Int,
        height: Int,
        values: [Float]
    ) {
        self.width = width
        self.height = height
        self.values = values
    }

    // MARK: - Public
    // A poster that does not repeat: value noise at three scales with rectangles and discs of other greys on it,
    // blurred by a Gaussian of one pixel so its detail is band-limited, as a lens leaves a camera's picture. The same
    // seed gives the same poster.
    package static func poster(
        width: Int,
        height: Int,
        seed: UInt64
    ) -> GreyTexture {
        var values = [Float](repeating: 0.5, count: width * height)
        for (octave, (cell, amplitude)) in [(24.0, 0.3), (8.0, 0.15), (3.0, 0.06)].enumerated() {
            let columns = Int(Double(width) / cell) + 2
            let lattice = (0..<(columns * (Int(Double(height) / cell) + 2))).map { index in
                unit(seed &+ UInt64(octave) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(index))
            }
            for y in 0..<height {
                let (row, down) = cellPosition(Double(y), cell: cell)
                for x in 0..<width {
                    let (column, across) = cellPosition(Double(x), cell: cell)
                    let upper = lattice[row * columns + column] * (1 - across) + lattice[row * columns + column + 1] * across
                    let lower = lattice[(row + 1) * columns + column] * (1 - across)
                        + lattice[(row + 1) * columns + column + 1] * across
                    values[y * width + x] += Float(amplitude * (upper * (1 - down) + lower * down - 0.5))
                }
            }
        }

        for shape in 0..<24 {
            let draw = { (index: UInt64) in unit(seed &+ 0xD1B5_4A32_D192_ED03 &* UInt64(shape * 8) &+ index) }
            let grey = Float(0.1 + 0.8 * draw(1))
            let centreX = draw(2) * Double(width)
            let centreY = draw(3) * Double(height)
            let reach = 4 + draw(4) * Double(min(width, height)) / 8
            for y in max(0, Int(centreY - reach))..<min(height, Int(centreY + reach)) {
                for x in max(0, Int(centreX - reach))..<min(width, Int(centreX + reach)) {
                    let isDisc = shape % 2 == 0
                    guard !isDisc || hypot(Double(x) + 0.5 - centreX, Double(y) + 0.5 - centreY) < reach else { continue }
                    values[y * width + x] = grey
                }
            }
        }

        return GreyTexture(width: width, height: height, values: values).blurred(sigma: 1)
    }

    // A screen: one flat grey inside a light bezel `bezel` pixels wide, with a lighter line along the bezel's inner
    // edge.
    package static func screen(
        width: Int,
        height: Int,
        bezel: Int
    ) -> GreyTexture {
        var values = [Float](repeating: 0.12, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let edge = min(x, y, width - 1 - x, height - 1 - y)
                if edge < bezel { values[y * width + x] = edge >= bezel - 3 ? 0.8 : 0.35 }
            }
        }

        return GreyTexture(width: width, height: height, values: values).blurred(sigma: 1)
    }

    // MARK: - Private
    // Uniform in [0, 1) for each input, by the SplitMix64 finaliser.
    private static func unit(_ value: UInt64) -> Double {
        var bits = value
        bits = (bits ^ (bits >> 30)) &* 0xBF58_476D_1CE4_E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D0_49BB_1331_11EB
        bits ^= bits >> 31

        return Double(bits >> 11) / Double(1 << 53)
    }

    // The lattice cell `position` lies in and where in it, eased by smoothstep so the noise has no creases.
    private static func cellPosition(
        _ position: Double,
        cell: Double
    ) -> (Int, Double) {
        let scaled = position / cell
        let index = Int(scaled)
        let fraction = scaled - Double(index)

        return (index, fraction * fraction * (3 - 2 * fraction))
    }

    // A separable Gaussian blur, the outer pixels repeated past the edges.
    private func blurred(sigma: Double) -> GreyTexture {
        let radius = Int((3 * sigma).rounded(.up))
        let kernel = (-radius...radius).map { Float(exp(-Double($0 * $0) / (2 * sigma * sigma))) }
        let total = kernel.reduce(0, +)
        let weights = kernel.map { $0 / total }
        var across = values
        var blurred = values
        for y in 0..<height {
            for x in 0..<width {
                across[y * width + x] = weights.indices.reduce(0) { sum, index in
                    sum + weights[index] * values[y * width + min(max(x + index - radius, 0), width - 1)]
                }
            }
        }
        for y in 0..<height {
            for x in 0..<width {
                blurred[y * width + x] = weights.indices.reduce(0) { sum, index in
                    sum + weights[index] * across[min(max(y + index - radius, 0), height - 1) * width + x]
                }
            }
        }

        return GreyTexture(width: width, height: height, values: blurred)
    }
}
