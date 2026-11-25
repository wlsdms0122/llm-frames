//
//  FrameDifference.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/26/26.
//

import Foundation

// Where two frames of half float RGBA pixels, `width` pixels a row and rows packed, differ, and by how much: the
// pixels and rows that differ, the box that holds them, rows counted from the top, and the largest difference of a
// component in steps of a half float, which tells a rounding of one step from pixels of another picture.
struct FrameDifference: CustomStringConvertible {
    // MARK: - Property
    let pixelCount: Int
    let rowCount: Int
    let box: (minX: Int, minY: Int, maxX: Int, maxY: Int)?
    let largestSteps: Int

    var description: String {
        guard let box else { return "no pixel differs" }

        return "\(pixelCount) pixels in \(rowCount) rows from (\(box.minX), \(box.minY)) to (\(box.maxX), \(box.maxY)) "
            + "differ, by at most \(largestSteps) steps of a half float"
    }

    // MARK: - Initializer
    init(
        of frame: Data,
        against reference: Data,
        width: Int
    ) {
        precondition(frame.count == reference.count, "frames of two sizes")

        let components = frame.withUnsafeBytes { Array($0.bindMemory(to: UInt16.self)) }
        let referenceComponents = reference.withUnsafeBytes { Array($0.bindMemory(to: UInt16.self)) }
        var pixels = Set<Int>()
        var rows = Set<Int>()
        var box: (minX: Int, minY: Int, maxX: Int, maxY: Int)?
        var largestSteps = 0
        for index in components.indices where components[index] != referenceComponents[index] {
            let pixel = index / 4
            let x = pixel % width
            let y = pixel / width
            pixels.insert(pixel)
            rows.insert(y)
            box = box.map { (min($0.minX, x), min($0.minY, y), max($0.maxX, x), max($0.maxY, y)) } ?? (x, y, x, y)
            largestSteps = max(
                largestSteps,
                abs(Self.ordered(components[index]) - Self.ordered(referenceComponents[index]))
            )
        }

        self.pixelCount = pixels.count
        self.rowCount = rows.count
        self.box = box
        self.largestSteps = largestSteps
    }

    // MARK: - Public
    // MARK: - Private
    // The half float's place among all half floats in order, negative values below zero.
    private static func ordered(_ bits: UInt16) -> Int {
        bits & 0x8000 == 0 ? Int(bits) : -Int(bits & 0x7FFF)
    }
}
