//
//  BlenderTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import Testing

@Suite("Blender Tests")
struct BlenderTests {
    // MARK: - Property
    // Backdrop and source colours as written. The third pair is saturated enough that the non-separable modes clip
    // their colour on both sides of the range; the last is half transparent on both sides.
    private static let pairs: [(backdrop: String, source: String)] = [
        ("#3366CC", "#CC9933"),
        ("#E61A80", "#4DB380"),
        ("#F0E010", "#2000F0"),
        ("#3366CC80", "#CC993380")
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "an item composites over its backdrop by its blend mode's W3C formula",
        arguments: BlendMode.allCases,
        pairs
    )
    func compositesByFormula(mode: BlendMode, pair: (backdrop: String, source: String)) throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 4, height: 4), color: Color(written: pair.source))
        let list = DisplayList(
            size: Size(width: 4, height: 4),
            background: Color(written: pair.backdrop),
            seed: 0,
            items: [DisplayItem(blend: mode.rawValue, content: .path(fill))]
        )

        // When
        let pixel = try sut.frame(of: list).pixel(x: 2, y: 2)

        // Then
        let expected = BlendFormula().composite(
            mode,
            source: components(of: pair.source),
            backdrop: components(of: pair.backdrop)
        )
        #expect(zip(pixel, expected).allSatisfy { abs($0 - $1) <= 1.0 / 1024 }, "\(pixel) is not \(expected)")
    }

    // MARK: - Private
    private func components(of written: String) -> [Double] {
        let hex = Color(written: written).hex.dropFirst()

        return stride(from: 0, to: 8, by: 2).map { start in
            let digits = hex.dropFirst(start).prefix(2)
            return Double(Int(digits, radix: 16)!) / 255
        }
    }
}
