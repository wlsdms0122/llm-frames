//
//  CornerPinWarperTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import CoreImage
import Frames
@testable import FramesQuartz
import FramesTestMedia
import Testing

@Suite("CornerPinWarper Tests")
struct CornerPinWarperTests {
    // MARK: - Property
    private static let side = 1024
    private static let box = Quad(Rectangle(x: 0, y: 0, width: 1024, height: 1024))

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a picture carried onto a corner pin lies within 0.1 of the area mean at every component and 0.005 on average",
        arguments: [Source.checkerboard, .grid], [Pin.mild, .steep]
    )
    func samplesArea(source: Source, pin: Pin) throws {
        // Given
        let sut = CornerPinWarper()
        let picture = source.picture
        let homography = try #require(Homography(from: Self.box, to: pin.quad))
        let destination = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        let mean = AreaMean(
            carrying: picture.pixels,
            width: picture.width,
            height: picture.height,
            through: homography,
            outputWidth: Self.side,
            outputHeight: Self.side
        )

        // When
        let carried = try sut.warp(picture.image, through: homography, onto: destination)
        let pixels = render(carried, width: Self.side, height: Self.side)

        // Then
        // Over the pixels either result covers.
        var worst: Float = 0
        var sum = 0.0
        var count = 0
        for pixel in 0..<(Self.side * Self.side) {
            let start = pixel * 4
            let components = start..<start + 4
            guard components.contains(where: { pixels[$0] != 0 || mean.pixels[$0] != 0 }) else { continue }

            for component in components {
                let error = abs(pixels[component] - mean.pixels[component])
                worst = max(worst, error)
                sum += Double(error)
                count += 1
            }
        }
        let average = sum / Double(count)
        #expect(count > 0)
        #expect(worst <= 0.1, "worst \(worst)")
        #expect(average <= 0.005, "mean \(average)")
    }

    @Test(
        "values carried onto a corner pin stay as they are one source pixel inside the edge, and nothing lies past the reconstruction",
        arguments: [[2, -0.5, 0.25, 0.5], [-1, 4, 0.1, 1], [0.3, 0, 0, 0]] as [[Float]], [Pin.mild, .steep]
    )
    func keepsValues(value: [Float], pin: Pin) throws {
        // Given
        let sut = CornerPinWarper()
        let held = value.map { Float(Float16($0)) }
        let picture = PixelGrid(
            width: Self.side,
            height: Self.side,
            pixels: Array([[Float]](repeating: held, count: Self.side * Self.side).joined())
        )
        let homography = try #require(Homography(from: Self.box, to: pin.quad))
        let inverse = homography.inverse
        let destination = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)

        // When
        let carried = try sut.warp(picture.image, through: homography, onto: destination)
        let pixels = render(carried, width: Self.side, height: Self.side)

        // Then
        // A pixel's image under the inverse map is the quad of its corners carried back. The reconstruction reaches half
        // a source pixel past the edge.
        var inside = 0
        var outside = 0
        for row in 0..<Self.side {
            for column in 0..<Self.side {
                let corners = [(0, 0), (1, 0), (1, 1), (0, 1)].compactMap {
                    inverse.apply(to: Point(x: Double(column + $0.0), y: Double(row + $0.1)))
                }
                guard corners.count == 4 else { continue }

                let start = (row * Self.side + column) * 4
                let pixel = Array(pixels[start..<start + 4])
                let limit = Double(Self.side)
                if corners.allSatisfy({ $0.x >= 1 && $0.y >= 1 && $0.x <= limit - 1 && $0.y <= limit - 1 }) {
                    inside += 1
                    let kept = zip(pixel, held).allSatisfy { abs($0 - $1) <= Float(Float16($1).ulp) }
                    #expect(kept, "\(pixel) at (\(column), \(row)) is not \(held)")
                }
                if corners.allSatisfy({ $0.x <= -0.5 }) || corners.allSatisfy({ $0.y <= -0.5 })
                    || corners.allSatisfy({ $0.x >= limit + 0.5 }) || corners.allSatisfy({ $0.y >= limit + 0.5 }) {
                    outside += 1
                    #expect(pixel == [0, 0, 0, 0], "\(pixel) at (\(column), \(row)) is not transparent")
                }
            }
        }
        #expect(inside > 100_000)
        #expect(outside > 100_000)
    }

    @Test("the corners of the source, not the centres of its corner pixels, land on the four points, its top row at the top")
    func landsCornersOnPoints() throws {
        // Given
        let sut = CornerPinWarper()
        let red: [Float] = [1, 0, 0, 1]
        let blue: [Float] = [0, 0, 1, 1]
        let picture = PixelGrid(
            width: 4,
            height: 3,
            pixels: Array((Array(repeating: red, count: 4) + Array(repeating: blue, count: 8)).joined())
        )
        let homography = try #require(
            Homography(
                from: Quad(Rectangle(x: 0, y: 0, width: 4, height: 3)),
                to: Quad(Rectangle(x: 10, y: 20, width: 4, height: 3))
            )
        )

        // When
        let carried = try sut.warp(picture.image, through: homography, onto: CGRect(x: 0, y: 0, width: 32, height: 32))
        let pixels = render(carried, width: 32, height: 32)

        // Then
        // Each axis's mean of the bilinear reconstruction over a pixel: 0.875 on an edge pixel and 0.125 on the pixel
        // past it, 1 inside. The red top row reaches 0.75 of its own row and nothing of the bottom row.
        func coverage(_ index: Int, _ count: Int) -> Float {
            switch index {
            case -1, count:
                0.125

            case 0, count - 1:
                0.875

            case 1..<(count - 1):
                1

            default:
                0
            }
        }
        for row in 0..<32 {
            for column in 0..<32 {
                let alpha = pixels[(row * 32 + column) * 4 + 3]
                let expected = coverage(column - 10, 4) * coverage(row - 20, 3)
                #expect(abs(alpha - expected) < 1e-3, "alpha \(alpha) at (\(column), \(row)) is not \(expected)")
            }
        }
        #expect(abs(pixels[(20 * 32 + 12) * 4] - 0.75) < 1e-3)
        #expect(pixels[(22 * 32 + 12) * 4] == 0)
    }

    @Test("what lies past the source's box in front of the horizon is carried, and nothing at or beyond the horizon is drawn")
    func cutsAtHorizon() throws {
        // Given
        let sut = CornerPinWarper()
        let color: [Float] = [0.2, 0.6, 0.4, 1]
        let height = 1400
        let picture = PixelGrid(width: Self.side, height: height, color: color)
        // The steep pin's horizon lies across the source at y = 1024 / 0.9, below the box's bottom edge.
        let homography = try #require(Homography(from: Self.box, to: Pin.steep.quad))
        let inverse = homography.inverse
        let destination = CGRect(x: 0, y: -Self.side, width: Self.side, height: 2 * Self.side)

        // When
        let carried = try sut.warp(picture.image, through: homography, onto: destination)
        let pixels = render(carried, width: Self.side, height: 2 * Self.side)

        // Then
        let finite = pixels.allSatisfy(\.isFinite)
        #expect(finite)
        var beyond = 0
        var past = 0
        for row in 0..<(2 * Self.side) {
            for column in 0..<Self.side {
                let x = Double(column)
                let y = Double(row - Self.side)
                let corners = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)].map { Point(x: x + $0.0, y: y + $0.1) }
                let start = (row * Self.side + column) * 4
                let pixel = Array(pixels[start..<start + 4])
                if corners.allSatisfy({ !inverse.isInFront($0) }) {
                    beyond += 1
                    #expect(pixel == [0, 0, 0, 0], "\(pixel) at (\(column), \(row - Self.side)) is drawn")
                    continue
                }

                let images = corners.compactMap { inverse.apply(to: $0) }
                let inSource = images.count == 4
                    && images.allSatisfy { $0.x >= 1 && $0.x <= Double(Self.side) - 1 && $0.y >= 1025 && $0.y <= 1130 }
                if inSource {
                    past += 1
                    let carriedColor = zip(pixel, color).allSatisfy { abs($0 - $1) < 1e-3 }
                    #expect(carriedColor, "\(pixel) at (\(column), \(row - Self.side))")
                }
            }
        }
        #expect(beyond > 10_000)
        #expect(past > 1_000)
    }

    @Test("a corner pin drawn again gives the same bytes")
    func drawsSameBytes() throws {
        // Given
        let sut = CornerPinWarper()
        let picture = Source.grid.picture
        let homography = try #require(Homography(from: Self.box, to: Pin.steep.quad))
        let destination = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)

        // When
        let first = try sut.warp(picture.image, through: homography, onto: destination)
        let second = try sut.warp(picture.image, through: homography, onto: destination)

        // Then
        #expect(render(first, width: Self.side, height: Self.side) == render(second, width: Self.side, height: Self.side))
    }

    // MARK: - Private
    // The image's pixels over `width` by `height` from its extent's origin, top row first, computed as the renderer
    // computes on the encoded form, in half float.
    private func render(
        _ image: CIImage,
        width: Int,
        height: Int
    ) -> [Float] {
        var pixels = [Float](repeating: 0, count: width * height * 4)
        WorkingSpace.context(of: .encoded).render(
            image,
            toBitmap: &pixels,
            rowBytes: width * 16,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .RGBAf,
            colorSpace: WorkingSpace.encoded
        )

        return pixels
    }
}

extension CornerPinWarperTests {
    // The two still sources of FRAMES-24's named set, 1024 × 1024 pixels, pixel (i, j) column i and row j from the
    // top left.
    enum Source: String, Sendable, CustomTestStringConvertible {
        // 32 px squares of (0.9, 0.25, 0.1) where ⌊i / 32⌋ + ⌊j / 32⌋ is even and (0.1, 0.35, 0.85) where it is odd,
        // premultiplied by an alpha of (i + 0.5) / 64 over the left 64 columns and 1 elsewhere, rounded to half floats.
        case checkerboard
        // Opaque black with white where i or j is a multiple of 4.
        case grid

        var testDescription: String {
            rawValue
        }

        var picture: PixelGrid {
            let side = CornerPinWarperTests.side
            var pixels = [Float](repeating: 0, count: side * side * 4)
            for row in 0..<side {
                for column in 0..<side {
                    let start = (row * side + column) * 4
                    let value: [Float]
                    switch self {
                    case .checkerboard:
                        let color: [Float] = (column / 32 + row / 32).isMultiple(of: 2) ? [0.9, 0.25, 0.1] : [0.1, 0.35, 0.85]
                        let alpha: Float = column < 64 ? (Float(column) + 0.5) / 64 : 1
                        value = (color.map { $0 * alpha } + [alpha]).map { Float(Float16($0)) }

                    case .grid:
                        let white = column.isMultiple(of: 4) || row.isMultiple(of: 4)
                        value = white ? [1, 1, 1, 1] : [0, 0, 0, 1]
                    }
                    pixels.replaceSubrange(start..<start + 4, with: value)
                }
            }

            return PixelGrid(width: side, height: side, pixels: pixels)
        }
    }

    // The two corner pins of FRAMES-24's named set, in y-down output pixels.
    enum Pin: String, Sendable, CustomTestStringConvertible {
        // 0.63 to 0.81 output pixels a source pixel.
        case mild
        // Its far edge a tenth of its near edge.
        case steep

        var testDescription: String {
            rawValue
        }

        var quad: Quad {
            switch self {
            case .mild:
                Quad(
                    topLeft: Point(x: 190, y: 164),
                    topRight: Point(x: 840, y: 124),
                    bottomRight: Point(x: 880, y: 854),
                    bottomLeft: Point(x: 150, y: 904)
                )

            case .steep:
                Quad(
                    topLeft: Point(x: 462, y: 24),
                    topRight: Point(x: 562, y: 24),
                    bottomRight: Point(x: 1012, y: 1004),
                    bottomLeft: Point(x: 12, y: 1004)
                )
            }
        }
    }
}
