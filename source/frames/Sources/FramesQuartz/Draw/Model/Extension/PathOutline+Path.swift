//
//  PathOutline+Path.swift
//  FramesQuartz
//
//  Created by JSilver on 11/18/26.
//

import CoreGraphics
import Frames

// An outline drawn as Core Graphics paths, along its segments from its start.
extension PathOutline {
    // MARK: - Property
    var path: CGPath {
        piece(from: 0, to: length, closing: isClosed)
    }

    // The outline closed by a straight segment from its end to its start, for its fill.
    var fillPath: CGPath {
        piece(from: 0, to: length, closing: true)
    }

    // MARK: - Initializer
    // MARK: - Public
    func piece(
        from start: Double,
        to end: Double
    ) -> CGPath {
        piece(from: start, to: end, closing: false)
    }

    // MARK: - Private
    private func piece(
        from start: Double,
        to end: Double,
        closing: Bool
    ) -> CGPath {
        let path = CGMutablePath()
        let first = point(at: start)
        path.move(to: CGPoint(x: first.x, y: first.y))

        // A whole closed outline leaves its last straight segment to the closing of the path, so its last corner and
        // the one at its start are joined as every other.
        let isWhole = closing && isClosed && start == 0 && end == length
        let drawn = isWhole && segments.last?.isLine == true ? segments.dropLast() : segments[...]
        var offset = 0.0
        for segment in drawn {
            let lower = max(start - offset, 0)
            let upper = min(end - offset, segment.length)
            if upper > lower { segment.append(from: lower, to: upper, to: path) }
            offset += segment.length
        }
        if closing { path.closeSubpath() }

        return path
    }
}
