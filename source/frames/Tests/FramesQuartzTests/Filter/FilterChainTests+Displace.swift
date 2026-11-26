//
//  FilterChainTests+Displace.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/23/26.
//

import CoreImage
import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import FramesTestMedia
import Testing

// A `displace` op (FRAMES-15 Displacement) on maps written as PNG files and read through the real decoder. Most tests
// displace a coordinate picture, whose red is its pixel's column and green its row from the top, so a pixel's red and
// green after the op are the point it read, the edge pixels extended outward, as bilinear interpolation of a ramp
// gives the ramp.
extension FilterChainTests {
    // MARK: - Test
    @Test(
        "a uniform map moves the picture by amount × (2m - 1), red along x and green along y pointing down, the edge pixels extended outward",
        arguments: [
            (65535, 65535, 1, 1),
            (0, 0, -1, -1),
            (65535, 0, 1, -1),
            (0, 65535, -1, 1),
            (65535, 32768, 1, 0),
            (32768, 65535, 0, 1)
        ]
    )
    func movesByUniformMap(
        red: Int,
        green: Int,
        columns: Int,
        rows: Int
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let map = try mapFile(in: directory, size: Size(width: 2, height: 2)) { _, _ in (red, green) }
        let grid = PixelGrid(width: 8, height: 6, pixels: (0..<48).flatMap { (index: Int) -> [Float] in
            let blue = Float((index * 7) % 11) / 11

            return [Float(index % 8) / 8, Float(index / 8) / 6, blue, 1]
        })
        let sut = displaceChain()

        // When
        let operation = ResolvedFilterOperation.displace(file: map, amount: 2, offset: Point(x: 0, y: 0))
        let result = PixelGrid(rendering: try sut.apply([FilterEntry(operations: [operation])], to: grid.image, seed: 0, compositing: .encoded))

        // Then
        for row in 0..<6 {
            for column in 0..<8 {
                let read = grid.pixel(column: min(max(column + 2 * columns, 0), 7), row: min(max(row + 2 * rows, 0), 5))
                for (value, want) in zip(result.pixel(column: column, row: row), read) {
                    #expect(abs(value - want) < displaceTolerance, "pixel \(column), \(row)")
                }
            }
        }
    }

    @Test("a 16-bit map at 32768 leaves the picture as it is to within amount / 65535, and amount 0 leaves it exactly")
    func keepsPictureAtMidpoint() throws {
        // Given
        let directory = try TemporaryDirectory()
        let map = try mapFile(in: directory, size: Size(width: 3, height: 3)) { _, _ in (32768, 32768) }
        let grid = coordinatePicture(width: 6, height: 5)
        let sut = displaceChain()

        // When
        let still = ResolvedFilterOperation.displace(file: map, amount: 5, offset: Point(x: 0, y: 0))
        let identity = ResolvedFilterOperation.displace(file: map, amount: 0, offset: Point(x: 0, y: 0))
        let moved = PixelGrid(rendering: try sut.apply([FilterEntry(operations: [still])], to: grid.image, seed: 0, compositing: .encoded))
        let kept = PixelGrid(rendering: try sut.apply([FilterEntry(operations: [identity])], to: grid.image, seed: 0, compositing: .encoded))

        // Then
        #expect(kept.pixels == grid.pixels)
        for row in 0..<5 {
            for column in 0..<6 {
                let pixel = moved.pixel(column: column, row: row)
                #expect(abs(pixel[0] - Float(column)) <= 5 / 65535 + displaceTolerance, "pixel \(column), \(row)")
                #expect(abs(pixel[1] - Float(row)) <= 5 / 65535 + displaceTolerance, "pixel \(column), \(row)")
            }
        }
    }

    @Test(
        "a move of half a pixel interpolates the two neighbours by half in the form compositing names, the map's values taken as they are in either form",
        arguments: [Compositing.encoded, .linear]
    )
    func interpolatesHalfPixel(compositing: Compositing) throws {
        // Given
        // 49151 / 65535 lies within 2^-17 of 0.75, so amount 1 moves a pixel by half of one.
        let directory = try TemporaryDirectory()
        let map = try mapFile(in: directory, size: Size(width: 1, height: 1)) { _, _ in (49151, 32768) }
        let values: [Float] = [0, 1, 0.2, 0.6]
        let grid = PixelGrid(width: 4, height: 1, pixels: values.flatMap { [$0, $0, $0, 1] })
        let sut = displaceChain()

        // When
        let operation = ResolvedFilterOperation.displace(file: map, amount: 1, offset: Point(x: 0, y: 0))
        let result = PixelGrid(
            rendering: try sut.apply([FilterEntry(operations: [operation])], to: grid.image, seed: 0, compositing: compositing),
            compositing: compositing
        )

        // Then
        for column in 0..<4 {
            let pair = [values[column], values[min(column + 1, 3)]]
            let expected = compositing == .encoded
                ? pair.reduce(0, +) / 2
                : encodedValue(pair.map(linearLight).reduce(0, +) / 2)
            #expect(abs(result.pixel(column: column, row: 0)[0] - expected) < displaceTolerance, "column \(column)")
        }
    }

    @Test("offset by half the box swaps the halves of a two-tone map, stretched over the box with its pixels' centres interpolated")
    func swapsHalvesByOffset() throws {
        // Given
        let directory = try TemporaryDirectory()
        let map = try mapFile(in: directory, size: Size(width: 2, height: 1)) { column, _ in (column == 0 ? 65535 : 0, 32768) }
        let grid = coordinatePicture(width: 8, height: 4)
        let sut = displaceChain()

        // When
        let moves = try [0.0, 4.0].map { offset in
            let operation = ResolvedFilterOperation.displace(file: map, amount: 1, offset: Point(x: offset, y: 0))
            let result = PixelGrid(rendering: try sut.apply([FilterEntry(operations: [operation])], to: grid.image, seed: 0, compositing: .encoded))

            return (0..<8).map { column in result.pixel(column: column, row: 1)[0] - Float(column) }
        }

        // Then
        // The map's centres lie at 1/4 and 3/4 of the box, so m runs 0.625, 0.875, 0.875, 0.625, 0.375, 0.125,
        // 0.125, 0.375 across its eight columns, wrapping from the second centre to the first. Swapped, the first and
        // last columns read past the picture's edge, which holds them.
        let expected: [Float] = [0.25, 0.75, 0.75, 0.25, -0.25, -0.75, -0.75, -0.25]
        for column in 0..<8 {
            #expect(abs(moves[0][column] - expected[column]) < displaceTolerance, "column \(column)")
            let swapped = min(max(Float(column) + expected[(column + 4) % 8], 0), 7) - Float(column)
            #expect(abs(moves[1][column] - swapped) < displaceTolerance, "column \(column)")
        }
    }

    @Test(
        "a map smaller or larger than the box is stretched to it",
        arguments: [Size(width: 2, height: 3), Size(width: 20, height: 13)]
    )
    func stretchesMapToBox(mapSize: Size) throws {
        // Given
        let directory = try TemporaryDirectory()
        let codeValues = { (column: Int, row: Int) in (red: (column * 9_973 + row * 3_001) % 65536, green: (column * 2_003 + row * 7_919) % 65536) }
        let map = try mapFile(in: directory, size: mapSize, codeValues: codeValues)
        let grid = coordinatePicture(width: 8, height: 8)
        let sut = displaceChain()

        // When
        let operation = ResolvedFilterOperation.displace(file: map, amount: 1.5, offset: Point(x: 0, y: 0))
        let result = PixelGrid(rendering: try sut.apply([FilterEntry(operations: [operation])], to: grid.image, seed: 0, compositing: .encoded))

        // Then
        let field = MapField(size: mapSize, depth: 65535, codeValues: codeValues)
        expectMoves(result, width: 8, height: 8, matching: field, box: CGSize(width: 8, height: 8), from: (0, 0), offset: (0, 0), amount: 1.5)
    }

    @Test(
        "the map repeats beyond its edges, so at any offset the pixels across an edge are those of its other side, with no seam",
        arguments: [0.0, 2.5, -7.25, 16]
    )
    func wrapsAcrossMapEdge(offset: Double) throws {
        // Given
        // A ramp in red that jumps from its last column back to its first, read across its edge only by wrapping.
        let directory = try TemporaryDirectory()
        let codeValues = { (column: Int, _: Int) in (red: [16384, 32768, 49152, 65535][column], green: 32768) }
        let map = try mapFile(in: directory, size: Size(width: 4, height: 1), codeValues: codeValues)
        let grid = coordinatePicture(width: 16, height: 2)
        let sut = displaceChain()

        // When
        let operation = ResolvedFilterOperation.displace(file: map, amount: 2, offset: Point(x: offset, y: 0))
        let result = PixelGrid(rendering: try sut.apply([FilterEntry(operations: [operation])], to: grid.image, seed: 0, compositing: .encoded))

        // Then
        let field = MapField(size: Size(width: 4, height: 1), depth: 65535, codeValues: codeValues)
        expectMoves(result, width: 16, height: 2, matching: field, box: CGSize(width: 16, height: 2), from: (0, 0), offset: (offset, 0), amount: 2)
        // Between neighbouring columns m changes by at most 0.75 over a map pixel, four columns.
        let moves = (0..<16).map { column in result.pixel(column: column, row: 0)[0] - Float(column) }
        // Columns 1 to 13 read no further than the picture's edge, as a move lies from -1 to 2.
        for column in 2..<14 {
            #expect(abs(moves[column] - moves[column - 1]) <= 2 * 2 * 0.75 / 4 + displaceTolerance, "column \(column)")
        }
    }

    @Test("a value above 1 is moved as it is, and a transparent neighbour adds nothing to the colour, premultiplied")
    func movesPremultipliedUnclamped() throws {
        // Given
        let directory = try TemporaryDirectory()
        let map = try mapFile(in: directory, size: Size(width: 1, height: 1)) { _, _ in (49151, 32768) }
        let grid = PixelGrid(width: 4, height: 1, pixels: [
            3, 2.5, 1.5, 1,
            3, 2.5, 1.5, 1,
            1, 0.2, 0, 1,
            0, 0, 0, 0
        ])
        let sut = displaceChain()

        // When
        let operation = ResolvedFilterOperation.displace(file: map, amount: 1, offset: Point(x: 0, y: 0))
        let result = PixelGrid(rendering: try sut.apply([FilterEntry(operations: [operation])], to: grid.image, seed: 0, compositing: .encoded))

        // Then
        let wants: [[Float]] = [[3, 2.5, 1.5, 1], [2, 1.35, 0.75, 1], [0.5, 0.1, 0, 0.5], [0, 0, 0, 0]]
        for (column, want) in wants.enumerated() {
            for (value, expected) in zip(result.pixel(column: column, row: 0), want) {
                #expect(abs(value - expected) < displaceTolerance, "column \(column)")
            }
        }
        let color = result.color(column: 2, row: 0)
        #expect(abs(color[0] - 1) < displaceTolerance && abs(color[1] - 0.2) < displaceTolerance)
    }

    @Test("the map is laid over the frame the image holds part of, and amount and offset are scaled into its pixels")
    func laysMapOverFrame() throws {
        // Given
        let directory = try TemporaryDirectory()
        let codeValues = { (column: Int, row: Int) in (red: (column * 21_841 + row * 9_001) % 65536, green: (column * 5_051 + row * 30_011) % 65536) }
        let map = try mapFile(in: directory, size: Size(width: 4, height: 3), codeValues: codeValues)
        let grid = coordinatePicture(width: 8, height: 6)
        let image = grid.image.transformed(by: CGAffineTransform(translationX: 4, y: 2))
        let frame = CGRect(x: 0, y: 0, width: 16, height: 12)
        let sut = displaceChain()

        // When
        let operation = ResolvedFilterOperation.displace(file: map, amount: 1.5, offset: Point(x: 1, y: 0.5))
        let filtered = try sut.apply([FilterEntry(operations: [operation])], to: image, seed: 0, scale: 2, frame: frame, compositing: .encoded)
        let result = PixelGrid(rendering: filtered)

        // Then
        // The image's top left pixel is the frame's column 4 and row 4 from its top.
        #expect(filtered.extent == image.extent)
        let field = MapField(size: Size(width: 4, height: 3), depth: 65535, codeValues: codeValues)
        expectMoves(result, width: 8, height: 6, matching: field, box: CGSize(width: 16, height: 12), from: (4, 4), offset: (2, 1), amount: 3)
    }

    @Test("an 8-bit map at 128 moves by amount / 255, to within the decoder's half float of 128 / 255")
    func readsEightBitMidpoint() throws {
        // Given
        let directory = try TemporaryDirectory()
        let map = try mapFile(in: directory, size: Size(width: 2, height: 2), bitsPerComponent: 8) { _, _ in (128, 128) }
        let grid = coordinatePicture(width: 4, height: 4)
        let sut = displaceChain()

        // When
        let operation = ResolvedFilterOperation.displace(file: map, amount: 10, offset: Point(x: 0, y: 0))
        let result = PixelGrid(rendering: try sut.apply([FilterEntry(operations: [operation])], to: grid.image, seed: 0, compositing: .encoded))

        // Then
        // A half float lies within 2^-12 of a value from 0.5 to 1, so the move lies within amount / 2048 of it.
        let pixel = result.pixel(column: 1, row: 1)
        #expect(abs(pixel[0] - 1 - 10.0 / 255) < 10.0 / 2048 + displaceTolerance)
        #expect(abs(pixel[1] - 1 - 10.0 / 255) < 10.0 / 2048 + displaceTolerance)
    }

    @Test("an entry with a displace op mixes the moved picture with its input by its mix")
    func mixesDisplacement() throws {
        // Given
        let directory = try TemporaryDirectory()
        let map = try mapFile(in: directory, size: Size(width: 1, height: 1)) { _, _ in (65535, 32768) }
        let grid = coordinatePicture(width: 6, height: 1)
        let sut = displaceChain()

        // When
        let operation = ResolvedFilterOperation.displace(file: map, amount: 2, offset: Point(x: 0, y: 0))
        let result = PixelGrid(rendering: try sut.apply([FilterEntry(operations: [operation], mix: 0.25)], to: grid.image, seed: 0, compositing: .encoded))

        // Then
        for column in 0..<6 {
            let expected = 0.75 * Float(column) + 0.25 * Float(min(column + 2, 5))
            #expect(abs(result.pixel(column: column, row: 0)[0] - expected) < displaceTolerance, "column \(column)")
        }
    }

    // MARK: - Private
    // The kernel computes in 32-bit floats on values up to about 20.
    private var displaceTolerance: Float {
        1.0 / 4096
    }

    private func displaceChain() -> FilterChain {
        FilterChain(
            tables: LookUpTableCache(),
            pictures: MediaPictureCache(decoder: AVFoundationDecoder(), budget: MemoryBudget(limit: .unlimited))
        )
    }

    private func mapFile(
        in directory: TemporaryDirectory,
        size: Size,
        bitsPerComponent: Int = 16,
        codeValues: (_ column: Int, _ row: Int) -> (red: Int, green: Int)
    ) throws -> PinnedFile {
        let path = directory.file("map-\(UUID().uuidString).png")
        try DisplacementMapWriter(size: size, bitsPerComponent: bitsPerComponent).write(to: path, codeValues: codeValues)

        return PinnedFile(path: path, sha256: "")
    }

    // Red the column and green the row from the top, opaque.
    private func coordinatePicture(
        width: Int,
        height: Int
    ) -> PixelGrid {
        PixelGrid(width: width, height: height, pixels: (0..<width * height).flatMap { (index: Int) -> [Float] in
            [Float(index % width), Float(index / width), 0.25, 1]
        })
    }

    // Expects each pixel of `result`, a coordinate picture displaced, to have read the point the spec gives: its centre
    // moved by `amount` × (2m - 1), m sampled from `field` laid over `box`, whose column and row `origin` is the
    // image's top left pixel, moved by `offset`, all in the image's pixels, y pointing down, clamped to the image.
    private func expectMoves(
        _ result: PixelGrid,
        width: Int,
        height: Int,
        matching field: MapField,
        box: CGSize,
        from origin: (column: Double, row: Double),
        offset: (x: Double, y: Double),
        amount: Double,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for row in 0..<height {
            for column in 0..<width {
                let x = origin.column + Double(column) + 0.5
                let y = origin.row + Double(row) + 0.5
                let m = field.value(at: ((x - offset.x) / box.width, (y - offset.y) / box.height))
                let read = (
                    min(max(Double(column) + amount * (2 * m.red - 1), 0), Double(width - 1)),
                    min(max(Double(row) + amount * (2 * m.green - 1), 0), Double(height - 1))
                )
                let pixel = result.pixel(column: column, row: row)
                #expect(
                    abs(Double(pixel[0]) - read.0) < Double(displaceTolerance)
                        && abs(Double(pixel[1]) - read.1) < Double(displaceTolerance),
                    "pixel \(column), \(row): \(pixel[0]), \(pixel[1]) for \(read)",
                    sourceLocation: sourceLocation
                )
            }
        }
    }

    // The extended sRGB transfer of FRAMES-26, to linear light and back.
    private func linearLight(_ value: Float) -> Float {
        Float(TransferFunction.sRGB.decode(Double(value)))
    }

    private func encodedValue(_ value: Float) -> Float {
        Float(TransferFunction.sRGB.encode(Double(value)))
    }
}
