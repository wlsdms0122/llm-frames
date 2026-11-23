//
//  MapField.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/23/26.
//

import Frames

// The values of a displacement map as FRAMES-15 Displacement samples them, for a test to compare a renderer with: its
// code values over `depth`, held as the decoder holds them in half floats, read at a point of its unit square modulo 1,
// bilinear between its pixels' centres, the pixels across an edge being those of its other side.
struct MapField {
    // MARK: - Property
    private let width: Int
    private let height: Int
    private let values: [(red: Double, green: Double)]

    // MARK: - Initializer
    // `codeValues` gives the red and green code values of the pixel at a column and row from the top left.
    init(
        size: Size,
        depth: Int,
        codeValues: (_ column: Int, _ row: Int) -> (red: Int, green: Int)
    ) {
        let width = Int(size.width)
        let height = Int(size.height)
        let held = { (code: Int) in Double(Float16(Double(code) / Double(depth))) }

        self.width = width
        self.height = height
        self.values = (0..<height).flatMap { row in
            (0..<width).map { column in
                let code = codeValues(column, row)

                return (held(code.red), held(code.green))
            }
        }
    }

    // MARK: - Public
    // `point` is in the map's unit square, y pointing down.
    func value(at point: (x: Double, y: Double)) -> (red: Double, green: Double) {
        let x = (point.x - point.x.rounded(.down)) * Double(width) - 0.5
        let y = (point.y - point.y.rounded(.down)) * Double(height) - 0.5
        let left = x.rounded(.down)
        let top = y.rounded(.down)
        let across = x - left
        let down = y - top
        let columns = [wrapped(Int(left), width), wrapped(Int(left) + 1, width)]
        let rows = [wrapped(Int(top), height), wrapped(Int(top) + 1, height)]
        let pixel = { (column: Int, row: Int) in values[rows[row] * width + columns[column]] }
        let mix = { (first: Double, second: Double, weight: Double) in first + (second - first) * weight }
        let red = mix(mix(pixel(0, 0).red, pixel(1, 0).red, across), mix(pixel(0, 1).red, pixel(1, 1).red, across), down)
        let green = mix(
            mix(pixel(0, 0).green, pixel(1, 0).green, across),
            mix(pixel(0, 1).green, pixel(1, 1).green, across),
            down
        )

        return (red, green)
    }

    // MARK: - Private
    private func wrapped(
        _ index: Int,
        _ count: Int
    ) -> Int {
        (index % count + count) % count
    }
}
