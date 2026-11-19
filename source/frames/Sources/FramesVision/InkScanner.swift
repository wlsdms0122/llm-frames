//
//  InkScanner.swift
//  FramesVision
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames

// Cuts a line's rectangle to the rows of the picture inside it that hold ink. Ink is a pixel whose colour differs
// from the rectangle's background, the median colour of its edge pixels, by more than half the largest difference
// any pixel inside it has, so the cut holds for dark text on light and light text on dark alike.
struct InkScanner: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The rectangle with its width kept, from its first to its last row holding ink, or unchanged when no pixel in it
    // differs from its background.
    func fitted(
        _ rectangle: Rectangle,
        in picture: Bitmap
    ) -> Rectangle {
        let columns = pixels(from: rectangle.x, to: rectangle.x + rectangle.width, within: picture.width)
        let rows = pixels(from: rectangle.y, to: rectangle.y + rectangle.height, within: picture.height)
        guard !columns.isEmpty, !rows.isEmpty else { return rectangle }

        let distances = picture.pixels.withUnsafeBytes { bytes in
            let color = { (x: Int, y: Int) in self.color(at: x, y, of: picture, in: bytes) }
            let edge = columns.flatMap { [color($0, rows.lowerBound), color($0, rows.upperBound - 1)] }
                + rows.flatMap { [color(columns.lowerBound, $0), color(columns.upperBound - 1, $0)] }
            let background = median(of: edge)

            return rows.map { y in columns.map { distance(color($0, y), background) }.max() ?? 0 }
        }
        let farthest = distances.max() ?? 0
        guard
            farthest > 0,
            let first = distances.firstIndex(where: { $0 * 2 > farthest }),
            let last = distances.lastIndex(where: { $0 * 2 > farthest })
        else {
            return rectangle
        }

        return Rectangle(
            x: rectangle.x,
            y: Double(rows.lowerBound + first),
            width: rectangle.width,
            height: Double(last - first + 1)
        )
    }

    // MARK: - Private
    // The pixels a span from `start` to `end` touches, cut to `0..<count`.
    private func pixels(
        from start: Double,
        to end: Double,
        within count: Int
    ) -> Range<Int> {
        let lower = max(0, Int(max(start, 0).rounded(.down)))
        let upper = min(count, Int(min(end, Double(count)).rounded(.up)))

        return lower..<max(lower, upper)
    }

    // The red, green and blue components of a pixel as stored, at the picture's depth, a half float's at the sixteen bit
    // scale.
    private func color(
        at x: Int,
        _ y: Int,
        of picture: Bitmap,
        in bytes: UnsafeRawBufferPointer
    ) -> [Int] {
        switch picture.depth {
        case .eight:
            let offset = y * picture.bytesPerRow + x * 4
            return (0..<3).map { Int(bytes[offset + $0]) }

        case .sixteen:
            let offset = y * picture.bytesPerRow + x * 8
            return (0..<3).map { Int(bytes.loadUnaligned(fromByteOffset: offset + $0 * 2, as: UInt16.self)) }

        case .halfFloat:
            let offset = y * picture.bytesPerRow + x * 8
            return (0..<3).map { component in
                let bits = bytes.loadUnaligned(fromByteOffset: offset + component * 2, as: UInt16.self)
                return Int((Float(Float16(bitPattern: bits)) * 65_535).rounded())
            }
        }
    }

    private func median(of colors: [[Int]]) -> [Int] {
        (0..<3).map { component in
            let sorted = colors.map { $0[component] }.sorted()

            return sorted[sorted.count / 2]
        }
    }

    // The largest difference of one component, so text that differs from its background only in hue is ink too.
    private func distance(
        _ color: [Int],
        _ other: [Int]
    ) -> Int {
        zip(color, other).map { abs($0 - $1) }.max() ?? 0
    }
}
