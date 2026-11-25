//
//  EdgeProbe.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/25/26.
//

import Frames

// A straight edge of alpha that crosses a window of the frame at right angles, alpha 1 at the pixel `inside` and 0 at
// the pixel `outside`, both counted across the edge, on every line of `along`. Its position, in pixels from the
// frame's left (a vertical edge) or top (a horizontal one), is found from the area the window's alpha covers: alpha
// summed from the inside pixel to the outside one is the covered length past the inside pixel's near side. The mean
// over the lines is the edge's position, which any filter that keeps a picture's area gives where the edge lies.
struct EdgeProbe: Sendable {
    // MARK: - Property
    let name: String
    // Whether the edge runs down the frame, so `inside` and `outside` are columns and `along` rows.
    let isVertical: Bool
    let inside: Int
    let outside: Int
    let along: Range<Int>

    // MARK: - Initializer
    // MARK: - Public
    func position(in frame: Bitmap) -> Double {
        let first = min(inside, outside)
        let last = max(inside, outside)
        var total = 0.0
        for line in along {
            var covered = 0.0
            for across in first...last {
                covered += isVertical ? frame.pixel(x: across, y: line)[3] : frame.pixel(x: line, y: across)[3]
            }
            total += inside < outside ? Double(inside) + covered : Double(inside + 1) - covered
        }

        return total / Double(along.count)
    }

    // MARK: - Private
}
