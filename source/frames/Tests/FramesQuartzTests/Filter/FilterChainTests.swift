//
//  FilterChainTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import CoreImage
import Foundation
import Frames
@testable import FramesQuartz
import FramesTestMedia
import Testing

@Suite("FilterChain Tests")
struct FilterChainTests {
    // MARK: - Property
    // A few 1/65535: the kernels compute in 32-bit floats.
    private let tolerance: Float = 4 / 65535
    // Core Image's blur of a step edge lies within 0.0018 of the continuous Gaussian at deviations 2, 3 and 5.
    private let blurTolerance: Float = 0.003

    // Unpremultiplied colours with their alpha, the last one half transparent.
    private let colors: [[Float]] = [
        [0.2, 0.5, 0.8, 1],
        [0.9, 0.1, 0.4, 1],
        [0.03, 0.6, 0.99, 1],
        [0.5, 0.5, 0.5, 1],
        [0.7, 0.35, 0.15, 0.5]
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a colour operation computes its formula on the unpremultiplied colour, clamps it and keeps alpha",
        arguments: [
            ResolvedFilterOperation.exposure(ev: 1),
            .exposure(ev: -0.5),
            .contrast(amount: 1.3),
            .contrast(amount: 0.5),
            .saturation(amount: 0),
            .saturation(amount: 1.8),
            .temperature(kelvin: 0),
            .temperature(kelvin: 1500),
            .temperature(kelvin: -3000),
            .hue(degrees: 90),
            .hue(degrees: -200),
            .sepia(amount: 1),
            .sepia(amount: 0.4),
            .levels(input: [0.1, 0.9], output: [0.05, 0.8]),
            .levels(input: [0, 0.5], output: [0, 1])
        ]
    )
    func computesColorOperation(operation: ResolvedFilterOperation) throws {
        // Given
        let grid = PixelGrid(width: colors.count, height: 1, pixels: Array(colors.map(premultiplied).joined()))
        let sut = FilterChain()

        // When
        let result = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 0))

        // Then
        for (column, color) in colors.enumerated() {
            let expected = expectedColor(of: operation, color)
            let pixel = result.pixel(column: column, row: 0)
            #expect(abs(pixel[3] - color[3]) < tolerance)
            for channel in 0..<3 {
                #expect(abs(pixel[channel] - expected[channel] * color[3]) < tolerance, "\(operation) \(color)")
            }
        }
    }

    @Test("an operation that overshoots is clamped to 0 to 1 before the next one reads it")
    func clampsBeforeNextOperation() throws {
        // Given
        let grid = PixelGrid(width: 1, height: 1, color: [0.9, 0.05, 0.5, 1])
        let operations = [ResolvedFilterOperation.contrast(amount: 3), .contrast(amount: 0.5)]
        let sut = FilterChain()

        // When
        let result = PixelGrid(rendering: try sut.apply(operations, to: grid.image, seed: 0))

        // Then
        // 0.9 overshoots to 1.7 and is clamped to 1, and 0.05 to -0.85 and is clamped to 0, before halving the
        // contrast; 0.5 stays.
        let expected: [Float] = [0.75, 0.25, 0.5, 1]
        for (value, want) in zip(result.pixel(column: 0, row: 0), expected) {
            #expect(abs(value - want) < tolerance)
        }
    }

    @Test("the operations apply in order, so contrast then saturation differs from saturation then contrast")
    func appliesInOrder() throws {
        // Given
        // Contrast and saturation commute while nothing clamps, as the luma weights sum to 1, so the colour is chosen
        // for contrast to clamp red and blue before saturation reads them.
        let color: [Float] = [0.9, 0.2, 0.1, 1]
        let grid = PixelGrid(width: 1, height: 1, color: color)
        let contrast = ResolvedFilterOperation.contrast(amount: 2)
        let saturation = ResolvedFilterOperation.saturation(amount: 0.5)
        let sut = FilterChain()

        // When
        let first = PixelGrid(rendering: try sut.apply([contrast, saturation], to: grid.image, seed: 0))
        let second = PixelGrid(rendering: try sut.apply([saturation, contrast], to: grid.image, seed: 0))

        // Then
        let expectedFirst = expectedColor(of: saturation, expectedColor(of: contrast, color) + [1])
        let expectedSecond = expectedColor(of: contrast, expectedColor(of: saturation, color) + [1])
        for channel in 0..<3 {
            #expect(abs(first.pixel(column: 0, row: 0)[channel] - expectedFirst[channel]) < tolerance)
            #expect(abs(second.pixel(column: 0, row: 0)[channel] - expectedSecond[channel]) < tolerance)
        }
        #expect(zip(expectedFirst, expectedSecond).contains { abs($0 - $1) > 0.05 })
    }

    @Test(
        "every operation keeps the image's extent",
        arguments: [
            ResolvedFilterOperation.exposure(ev: 1),
            .contrast(amount: 1.3),
            .saturation(amount: 0.5),
            .temperature(kelvin: 800),
            .hue(degrees: 30),
            .sepia(amount: 0.5),
            .levels(input: [0.1, 0.9], output: [0, 1]),
            .blur(radius: 3),
            .sharpen(amount: 0.8, radius: 2),
            .bloom(amount: 0.5, radius: 3, color: Color(written: "#FFAA88")),
            .vignette(amount: 0.6, radius: 0.4),
            .pixelate(size: 3.5),
            .grain(amount: 0.2, size: 2)
        ]
    )
    func keepsExtent(operation: ResolvedFilterOperation) throws {
        // Given
        let extent = CGRect(x: 10, y: 20, width: 13, height: 9)
        let image = PixelGrid(width: 13, height: 9, color: [0.6, 0.4, 0.8, 1]).image
            .transformed(by: CGAffineTransform(translationX: 10, y: 20))
        let sut = FilterChain()

        // When
        let result = try sut.apply([operation], to: image, seed: 3)

        // Then
        #expect(result.extent == extent)
    }

    @Test(
        "blur, sharpen and bloom read the edge pixels extended outward, so a flat image stays flat to its edges",
        arguments: [
            ResolvedFilterOperation.blur(radius: 5),
            .sharpen(amount: 1.5, radius: 4),
            .bloom(amount: 0.5, radius: 6, color: nil)
        ]
    )
    func extendsEdges(operation: ResolvedFilterOperation) throws {
        // Given
        let color: [Float] = [0.3, 0.6, 0.9, 1]
        let grid = PixelGrid(width: 16, height: 12, color: color)
        let sut = FilterChain()

        // When
        let result = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 0))

        // Then
        let centre = result.pixel(column: 8, row: 6)
        for row in 0..<12 {
            for column in 0..<16 {
                for (value, want) in zip(result.pixel(column: column, row: row), centre) {
                    #expect(abs(value - want) < tolerance)
                }
            }
        }
    }

    @Test(
        "blur is a Gaussian whose standard deviation is the radius",
        arguments: [2.0, 5.0]
    )
    func blursByStandardDeviation(radius: Double) throws {
        // Given
        let grid = stepEdge(width: 64)
        let sut = FilterChain()

        // When
        let result = PixelGrid(rendering: try sut.apply([.blur(radius: radius)], to: grid.image, seed: 0))

        // Then
        for column in 0..<64 {
            let expected = Float(gaussianStep(at: Double(column) + 0.5, edge: 32, deviation: radius))
            #expect(abs(result.pixel(column: column, row: 0)[0] - expected) < blurTolerance, "column \(column)")
        }
    }

    @Test(
        "sharpen is the unsharp mask v + amount × (v - blur(v)), clamped",
        arguments: [(0.5, 2.0), (2.0, 3.0)]
    )
    func sharpensByUnsharpMask(
        amount: Double,
        radius: Double
    ) throws {
        // Given
        let grid = stepEdge(width: 64)
        let sut = FilterChain()

        // When
        let operation = ResolvedFilterOperation.sharpen(amount: amount, radius: radius)
        let result = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 0))

        // Then
        // The blur's error is scaled by amount.
        let sharpenTolerance = blurTolerance * Float(amount)
        for column in 0..<64 {
            let value = Double(column) + 0.5 < 32 ? 0.0 : 1.0
            let blurred = gaussianStep(at: Double(column) + 0.5, edge: 32, deviation: radius)
            let expected = Float(min(max(value + amount * (value - blurred), 0), 1))
            #expect(abs(result.pixel(column: column, row: 0)[0] - expected) < sharpenTolerance, "column \(column)")
        }
    }

    @Test(
        "bloom adds amount × the blur of the bright parts, times its colour when it has one, clamped",
        arguments: [
            ([Float](arrayLiteral: 0.9, 0.85, 0.7), 0.5, nil as Color?),
            ([0.6, 0.6, 0.6], 1.0, nil),
            ([0.95, 0.9, 0.9], 0.8, Color(written: "#FF8040")),
            ([0.3, 0.2, 0.1], 1.0, nil)
        ]
    )
    func addsBloom(
        color: [Float],
        amount: Double,
        tint: Color?
    ) throws {
        // Given
        let grid = PixelGrid(width: 12, height: 12, color: color + [1])
        let sut = FilterChain()

        // When
        let operation = ResolvedFilterOperation.bloom(amount: amount, radius: 3, color: tint)
        let result = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 0))

        // Then
        // The blur of a flat image is the image, so each pixel gains amount × v × smoothstep(0.5, 1, L) × colour.
        let weight = smoothstep(0.5, 1, luma(color))
        let tintComponents = tint.map(components) ?? [1, 1, 1]
        for channel in 0..<3 {
            let expected = clamped(color[channel] + Float(amount) * color[channel] * weight * tintComponents[channel])
            #expect(abs(result.pixel(column: 5, row: 7)[channel] - expected) < tolerance)
        }
    }

    @Test("bloom spreads the bright parts into their dark neighbours")
    func spreadsBloom() throws {
        // Given
        var pixels = [Float]()
        for _ in 0..<9 {
            for column in 0..<9 {
                pixels += column == 4 ? [1, 1, 1, 1] : [0, 0, 0, 1]
            }
        }
        let grid = PixelGrid(width: 9, height: 9, pixels: pixels)
        let sut = FilterChain()

        // When
        let result = PixelGrid(rendering: try sut.apply([.bloom(amount: 1, radius: 1.5, color: nil)], to: grid.image, seed: 0))

        // Then
        #expect(result.pixel(column: 3, row: 4)[0] > 0.1)
        #expect(result.pixel(column: 0, row: 4)[0] < result.pixel(column: 3, row: 4)[0])
    }

    @Test(
        "vignette multiplies by 1 - amount × smoothstep(radius, 1, d), d from the centre over half the diagonal",
        arguments: [(0.7, 0.3), (1.0, 0.0), (0.5, 1.0)]
    )
    func darkensByVignette(
        amount: Double,
        radius: Double
    ) throws {
        // Given
        let color: [Float] = [0.8, 0.6, 0.4, 0.5]
        let grid = PixelGrid(width: 8, height: 6, color: color)
        let sut = FilterChain()

        // When
        let operation = ResolvedFilterOperation.vignette(amount: amount, radius: radius)
        let result = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 0))

        // Then
        let halfDiagonal = (8.0 * 8.0 + 6.0 * 6.0).squareRoot() / 2
        for row in 0..<6 {
            for column in 0..<8 {
                let x = Double(column) + 0.5 - 4
                let y = Double(row) + 0.5 - 3
                let distance = (x * x + y * y).squareRoot() / halfDiagonal
                let falloff = radius < 1 ? smoothstep(Float(radius), 1, Float(distance)) : (distance < 1 ? 0 : 1)
                let factor = 1 - Float(amount) * falloff
                let pixel = result.pixel(column: column, row: row)
                #expect(abs(pixel[3] - color[3]) < tolerance)
                for channel in 0..<3 {
                    #expect(abs(pixel[channel] - color[channel] * factor * color[3]) < tolerance)
                }
            }
        }
    }

    @Test(
        "pixelate fills square blocks from the top left with the mean of the pixels whose centres they hold",
        arguments: [3.0, 2.5, 1.0, 4.0]
    )
    func pixelatesByBlockMean(size: Double) throws {
        // Given
        let width = 7
        let height = 5
        let grid = PixelGrid(width: width, height: height, pixels: (0..<width * height).flatMap { index in
            [Float(index % 7) / 7, Float(index % 5) / 5, Float((index * 13) % 11) / 11, 1]
        })
        let sut = FilterChain()

        // When
        let result = PixelGrid(rendering: try sut.apply([.pixelate(size: size)], to: grid.image, seed: 0))

        // Then
        let block = { (index: Int) in Int(((Double(index) + 0.5) / size).rounded(.down)) }
        for row in 0..<height {
            for column in 0..<width {
                let members = (0..<height).flatMap { memberRow in
                    (0..<width).compactMap { memberColumn in
                        block(memberRow) == block(row) && block(memberColumn) == block(column)
                            ? grid.pixel(column: memberColumn, row: memberRow)
                            : nil
                    }
                }
                let pixel = result.pixel(column: column, row: row)
                for channel in 0..<4 {
                    let mean = members.map { $0[channel] }.reduce(0, +) / Float(members.count)
                    #expect(abs(pixel[channel] - mean) < tolerance, "pixel \(column), \(row)")
                }
            }
        }
    }

    @Test("grain on a flat mid-grey adds amount × n, where n has a standard deviation of 1")
    func addsGrainOfUnitDeviation() throws {
        // Given
        let amount: Float = 0.1
        let grid = PixelGrid(width: 256, height: 256, color: [0.5, 0.5, 0.5, 1])
        let sut = FilterChain()

        // When
        let operation = ResolvedFilterOperation.grain(amount: Double(amount), size: 1)
        let result = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 7))

        // Then
        let noise = stride(from: 0, to: result.pixels.count, by: 4).map { (result.pixels[$0] - 0.5) / amount }
        let mean = noise.reduce(0, +) / Float(noise.count)
        let deviation = (noise.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(noise.count)).squareRoot()
        #expect(abs(mean) < 0.02)
        #expect(abs(deviation - 1) < 0.05)
        for index in stride(from: 0, to: result.pixels.count, by: 4) {
            #expect(result.pixels[index] == result.pixels[index + 1] && result.pixels[index] == result.pixels[index + 2])
        }
    }

    @Test("grain is a function of the seed: the same seed gives the same grain, and another seed another")
    func drawsGrainFromSeed() throws {
        // Given
        let grid = PixelGrid(width: 32, height: 32, color: [0.4, 0.5, 0.6, 1])
        let operation = ResolvedFilterOperation.grain(amount: 0.3, size: 1.5)
        let sut = FilterChain()

        // When
        let first = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 12))
        let again = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 12))
        let other = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 13))

        // Then
        #expect(first.pixels == again.pixels)
        #expect(first.pixels != other.pixels)
    }

    @Test("grains are squares size pixels across on a grid from the top left, each one noise value")
    func drawsGrainsOfSize() throws {
        // Given
        let grid = PixelGrid(width: 12, height: 8, color: [0.5, 0.5, 0.5, 1])
        let sut = FilterChain()

        // When
        let result = PixelGrid(rendering: try sut.apply([.grain(amount: 0.2, size: 4)], to: grid.image, seed: 1))

        // Then
        var grains: Set<Float> = []
        for row in 0..<8 {
            for column in 0..<12 {
                let corner = result.pixel(column: column / 4 * 4, row: row / 4 * 4)[0]
                #expect(result.pixel(column: column, row: row)[0] == corner)
                grains.insert(corner)
            }
        }
        #expect(grains.count == 6)
    }

    @Test(
        "lut maps the unpremultiplied colour through the cube with trilinear interpolation and blends by amount",
        arguments: [
            ([Float](arrayLiteral: 0.25, 0.5, 0.75, 1), 1.0),
            ([0, 1, 0.5, 1], 1.0),
            ([1, 1, 1, 1], 1.0),
            ([0.3, 0.8, 0.1, 0.5], 1.0),
            ([0.6, 0.2, 0.9, 1], 0.4)
        ]
    )
    func mapsThroughCube(
        color: [Float],
        amount: Double
    ) throws {
        // Given
        // Corner (red, green, blue) of a 2 × 2 × 2 cube, red varying fastest, chosen so no channel is affine.
        let corners: [[Float]] = [
            [0.1, 0.0, 0.2],
            [0.9, 0.3, 0.1],
            [0.2, 0.8, 0.0],
            [0.7, 0.6, 0.9],
            [0.0, 0.1, 1.0],
            [1.0, 0.5, 0.4],
            [0.3, 0.9, 0.6],
            [0.8, 1.0, 0.7]
        ]
        let directory = try TemporaryDirectory()
        let path = directory.file("look.cube")
        let text = "LUT_3D_SIZE 2\n" + corners.map { $0.map { "\($0)" }.joined(separator: " ") }.joined(separator: "\n")
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        let operation = ResolvedFilterOperation.lut(file: PinnedFile(path: path, sha256: UUID().uuidString), amount: amount)
        let grid = PixelGrid(width: 1, height: 1, color: color)
        let sut = FilterChain(tables: LookUpTableCache())

        // When
        let result = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 0))

        // Then
        // Trilinear: each corner weighs the product of (1 - f) or f along each axis.
        var mapped: [Float] = [0, 0, 0]
        for (index, corner) in corners.enumerated() {
            let weight = (0..<3).map { axis in index >> axis & 1 == 1 ? color[axis] : 1 - color[axis] }.reduce(1, *)
            for channel in 0..<3 {
                mapped[channel] += weight * corner[channel]
            }
        }
        let pixel = result.pixel(column: 0, row: 0)
        #expect(abs(pixel[3] - color[3]) < tolerance)
        for channel in 0..<3 {
            let expected = color[channel] + Float(amount) * (mapped[channel] - color[channel])
            #expect(abs(pixel[channel] - expected * color[3]) < tolerance)
        }
    }

    @Test("lut reads the cube's domain, mapping its minimum to the first entry and its maximum to the last")
    func mapsThroughDomain() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("domain.cube")
        let text = """
            LUT_3D_SIZE 3
            DOMAIN_MIN 0.2 0.2 0.2
            DOMAIN_MAX 0.6 0.6 0.6
            """ + "\n" + (0..<27).map { index in
                "\(Double(index % 3) / 2) \(Double(index / 3 % 3) / 2) \(Double(index / 9) / 2)"
            }.joined(separator: "\n")
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        let operation = ResolvedFilterOperation.lut(file: PinnedFile(path: path, sha256: UUID().uuidString), amount: 1)
        let grid = PixelGrid(width: 1, height: 1, color: [0.1, 0.5, 0.7, 1])
        let sut = FilterChain(tables: LookUpTableCache())

        // When
        let result = PixelGrid(rendering: try sut.apply([operation], to: grid.image, seed: 0))

        // Then
        // The entries are the identity over [0, 1], so v maps to (v - 0.2) / 0.4, clamped to the domain.
        let expected: [Float] = [0, 0.75, 1]
        for channel in 0..<3 {
            #expect(abs(result.pixel(column: 0, row: 0)[channel] - expected[channel]) < tolerance)
        }
    }

    @Test("a malformed cube stops the chain naming its file and line")
    func stopsOnMalformedCube() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("broken.cube")
        try "LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".write(toFile: path, atomically: true, encoding: .utf8)
        let operation = ResolvedFilterOperation.lut(file: PinnedFile(path: path, sha256: UUID().uuidString), amount: 1)
        let grid = PixelGrid(width: 1, height: 1, color: [0.5, 0.5, 0.5, 1])
        let sut = FilterChain(tables: LookUpTableCache())

        // When
        let error = #expect(throws: FilterError.self) {
            try sut.apply([operation], to: grid.image, seed: 0)
        }

        // Then
        #expect(error?.description.hasPrefix("\(path): line 1: ") == true)
    }

    // MARK: - Private
    private func premultiplied(_ color: [Float]) -> [Float] {
        [color[0] * color[3], color[1] * color[3], color[2] * color[3], color[3]]
    }

    // FRAMES-15's formula for a colour operation on the unpremultiplied red, green and blue of `color`, clamped.
    private func expectedColor(
        of operation: ResolvedFilterOperation,
        _ color: [Float]
    ) -> [Float] {
        let v = Array(color[0..<3])
        let result: [Float]
        switch operation {
        case let .exposure(ev):
            result = v.map { encode(decode($0) * Float(pow(2, ev))) }

        case let .contrast(amount):
            result = v.map { ($0 - 0.5) * Float(amount) + 0.5 }

        case let .saturation(amount):
            let luma = luma(v)
            result = v.map { luma + Float(amount) * ($0 - luma) }

        case let .temperature(kelvin):
            let gain = ChannelGain(kelvin: kelvin)
            result = zip(v, [gain.red, gain.green, gain.blue]).map { encode(decode($0) * Float($1)) }

        case let .hue(degrees):
            let c = Float(cos(degrees * .pi / 180))
            let s = Float(sin(degrees * .pi / 180))
            result = multiplied([
                [0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928],
                [0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283],
                [0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072]
            ], v)

        case let .sepia(amount):
            let rest = Float(1 - amount)
            result = multiplied([
                [0.393 + 0.607 * rest, 0.769 - 0.769 * rest, 0.189 - 0.189 * rest],
                [0.349 - 0.349 * rest, 0.686 + 0.314 * rest, 0.168 - 0.168 * rest],
                [0.272 - 0.272 * rest, 0.534 - 0.534 * rest, 0.131 + 0.869 * rest]
            ], v)

        case let .levels(input, output):
            result = v.map { value in
                let level = clamped((value - Float(input[0])) / Float(input[1] - input[0]))

                return Float(output[0]) + level * Float(output[1] - output[0])
            }

        default:
            result = v
        }

        return result.map(clamped)
    }

    private func multiplied(
        _ matrix: [[Float]],
        _ v: [Float]
    ) -> [Float] {
        matrix.map { row in zip(row, v).map(*).reduce(0, +) }
    }

    private func decode(_ value: Float) -> Float {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private func encode(_ value: Float) -> Float {
        value <= 0.0031308 ? 12.92 * value : 1.055 * pow(value, 1 / 2.4) - 0.055
    }

    private func luma(_ v: [Float]) -> Float {
        0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]
    }

    private func clamped(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private func smoothstep(
        _ edge0: Float,
        _ edge1: Float,
        _ x: Float
    ) -> Float {
        let t = clamped((x - edge0) / (edge1 - edge0))

        return t * t * (3 - 2 * t)
    }

    private func components(_ color: Color) -> [Float] {
        let value = UInt32(color.hex.dropFirst(), radix: 16)!
        let alpha = Float(value & 0xFF) / 255

        return [value >> 24, value >> 16, value >> 8].map { Float($0 & 0xFF) / 255 * alpha }
    }

    // A one row image, black left of `width` / 2 and white from it.
    private func stepEdge(width: Int) -> PixelGrid {
        PixelGrid(width: width, height: 1, pixels: (0..<width).flatMap { column in
            column < width / 2 ? [Float](arrayLiteral: 0, 0, 0, 1) : [1, 1, 1, 1]
        })
    }

    // The Gaussian blur of a step from 0 to 1 at `edge`, at `x`.
    private func gaussianStep(
        at x: Double,
        edge: Double,
        deviation: Double
    ) -> Double {
        0.5 * (1 + erf((x - edge) / (deviation * 2.0.squareRoot())))
    }
}
