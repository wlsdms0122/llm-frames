//
//  InkScannerTests.swift
//  FramesVisionTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
import Testing

@testable import FramesVision

@Suite("InkScanner Tests")
struct InkScannerTests {
    // MARK: - Property
    // A 40 by 30 picture whose ink fills columns 10 to 30 of rows 8 to 18, and a line box over it reaching below.
    private let inkRows = 8..<18
    private let box = Rectangle(x: 6, y: 7, width: 28, height: 20)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a line box is cut to its rows of ink, keeping its width",
        arguments: [
            ([242, 244, 246], [0, 0, 0], BitDepth.eight),
            ([28, 28, 30], [255, 255, 255], .eight),
            ([0, 160, 0], [160, 0, 0], .eight),
            ([62_000, 62_500, 63_000], [0, 0, 0], .sixteen)
        ]
    )
    func cutsToInk(
        background: [Int],
        ink: [Int],
        depth: BitDepth
    ) {
        // Given
        let picture = bitmap(depth: depth, background: background) { _, y in inkRows.contains(y) ? ink : nil }
        let sut = InkScanner()

        // When
        let fitted = sut.fitted(box, in: picture)

        // Then
        #expect(fitted == Rectangle(x: 6, y: 8, width: 28, height: 10))
    }

    @Test("a row is ink only when it differs from the background by more than half the most any pixel does")
    func leavesFaintRows() {
        // Given
        let picture = bitmap(depth: .eight, background: [255, 255, 255]) { _, y in
            switch y {
            case 7:
                [128, 128, 128]

            case inkRows:
                [0, 0, 0]

            case 18:
                [126, 126, 126]

            default:
                nil
            }
        }
        let sut = InkScanner()

        // When
        let fitted = sut.fitted(box, in: picture)

        // Then
        #expect(fitted == Rectangle(x: 6, y: 8, width: 28, height: 11))
    }

    @Test("a line box over no ink is kept as it is")
    func keepsBoxWithoutInk() {
        // Given
        let picture = bitmap(depth: .eight, background: [255, 255, 255]) { _, _ in nil }
        let sut = InkScanner()

        // When
        let fitted = sut.fitted(box, in: picture)

        // Then
        #expect(fitted == box)
    }

    @Test("a line box reaching past the picture is scanned only where the picture is")
    func scansInsidePicture() {
        // Given
        let picture = bitmap(depth: .eight, background: [255, 255, 255]) { _, y in
            inkRows.contains(y) ? [0, 0, 0] : nil
        }
        let outside = Rectangle(x: -10, y: 4, width: 70, height: 40)
        let sut = InkScanner()

        // When
        let fitted = sut.fitted(outside, in: picture)

        // Then
        #expect(fitted == Rectangle(x: -10, y: 8, width: 70, height: 10))
    }

    // MARK: - Private
    // An opaque 40 by 30 picture of `background`, with the colour `ink` gives in columns 10 to 30 where it gives one.
    private func bitmap(
        depth: BitDepth,
        background: [Int],
        ink: (Int, Int) -> [Int]?
    ) -> Bitmap {
        let width = 40
        let height = 30
        let bytes = depth.bitsPerComponent / 8
        let bytesPerRow = width * 4 * bytes
        var pixels = Data(count: bytesPerRow * height)
        let opaque = (1 << depth.bitsPerComponent) - 1
        for y in 0..<height {
            for x in 0..<width {
                let color = (10..<30).contains(x) ? ink(x, y) ?? background : background
                for (component, value) in (color + [opaque]).enumerated() {
                    let offset = y * bytesPerRow + (x * 4 + component) * bytes
                    if depth == .sixteen {
                        withUnsafeBytes(of: UInt16(value)) { pixels.replaceSubrange(offset..<offset + 2, with: $0) }
                    } else {
                        pixels[offset] = UInt8(value)
                    }
                }
            }
        }

        return Bitmap(width: width, height: height, depth: depth, bytesPerRow: bytesPerRow, pixels: pixels)
    }
}
