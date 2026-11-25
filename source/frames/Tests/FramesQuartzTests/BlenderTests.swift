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
    // their colour on both sides of the range; the fourth is half transparent on both sides; the last two lie above 1
    // and below 0.
    private static let pairs: [(backdrop: String, source: String)] = [
        ("#3366CC", "#CC9933"),
        ("#E61A80", "#4DB380"),
        ("#F0E010", "#2000F0"),
        ("#3366CC80", "#CC993380"),
        ("color(srgb 1.5 1.2 0.3)", "color(srgb 1.3 0.6 1.6)"),
        ("color(srgb 0.4 -0.2 1.3)", "color(srgb 1.2 0.3 -0.1 / 0.6)")
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "an item composites over its backdrop by its blend mode's W3C formula",
        arguments: BlendMode.allCases,
        pairs
    )
    func compositesByFormula(mode: BlendMode, pair: (backdrop: String, source: String)) throws {
        for compositing in Compositing.allCases {
            // Given
            let list = list(backdrop: pair.backdrop, source: pair.source, mode: mode, compositing: compositing)

            // When
            let pixel = try QuartzRenderer(decoder: AVFoundationDecoder()).bitmap(of: list).pixel(x: 2, y: 2)

            // Then
            let expected = BlendFormula().composite(
                mode,
                source: components(of: pair.source),
                backdrop: components(of: pair.backdrop),
                compositing: compositing
            )
            #expect(
                zip(pixel, expected).allSatisfy { abs($0 - $1) <= 2.0 / 1024 + abs($1) / 512 },
                "\(compositing): \(pixel) is not \(expected)"
            )
        }
    }

    @Test(
        "a blend mode reads values above 1 as they are, so screen darkens them and add adds without bound",
        arguments: [
            (BlendMode.screen, "color(srgb 1.5 1.5 1.5)", "color(srgb 1.5 1.5 1.5)", Compositing.encoded, 0.75),
            (.add, "color(srgb 0.8 0.8 0.8)", "color(srgb 0.7 0.7 0.7)", .encoded, 1.5),
            (.add, "color(srgb 1.5 1.5 1.5)", "color(srgb 1.5 1.5 1.5)", .encoded, 3),
            (.add, "color(srgb 0.8 0.8 0.8)", "color(srgb 0.7 0.7 0.7)", .linear, 1.0222),
            (.multiply, "color(srgb 1.5 1.5 1.5)", "color(srgb 2 2 2)", .encoded, 3),
            (.plusLighter, "color(srgb 0.8 0.8 0.8)", "color(srgb 0.7 0.7 0.7)", .encoded, 1)
        ]
    )
    func readsValuesAsTheyAre(
        mode: BlendMode,
        backdrop: String,
        source: String,
        compositing: Compositing,
        expected: Double
    ) throws {
        // Given
        let list = list(backdrop: backdrop, source: source, mode: mode, compositing: compositing)

        // When
        let pixel = try QuartzRenderer(decoder: AVFoundationDecoder()).bitmap(of: list).pixel(x: 2, y: 2)

        // Then
        for channel in 0..<3 {
            #expect(abs(pixel[channel] - expected) < 0.004, "\(pixel)")
        }
    }

    @Test(
        "overlay and exclusion compute their blend function on the encoded form under either compositing",
        arguments: [(BlendMode.overlay, 0.72), (.exclusion, 0.62)]
    )
    func blendsOnEncodedForm(
        mode: BlendMode,
        expected: Double
    ) throws {
        for compositing in Compositing.allCases {
            // Given
            // Cb 0.8 and Cs 0.3, encoded: overlay screens 0.3 by 2 × 0.8 - 1, 0.3 + 0.6 - 0.18, and exclusion gives
            // 0.8 + 0.3 - 2 × 0.24.
            let list = list(backdrop: "color(srgb 0.8 0.8 0.8)", source: "color(srgb 0.3 0.3 0.3)", mode: mode, compositing: compositing)

            // When
            let pixel = try QuartzRenderer(decoder: AVFoundationDecoder()).bitmap(of: list).pixel(x: 2, y: 2)

            // Then
            for channel in 0..<3 {
                #expect(abs(pixel[channel] - expected) < 0.002, "\(compositing): \(pixel)")
            }
        }
    }

    @Test(
        "a half transparent item over another mixes code values under encoded and light under linear",
        arguments: [(Compositing.encoded, 0.5), (.linear, 0.7354)]
    )
    func dissolves(
        compositing: Compositing,
        expected: Double
    ) throws {
        // Given
        let list = list(backdrop: "#FF0000", source: "#0000FF80", mode: .normal, compositing: compositing)

        // When
        let pixel = try QuartzRenderer(decoder: AVFoundationDecoder()).bitmap(of: list).pixel(x: 2, y: 2)

        // Then
        // #80 is an alpha of 128 / 255, so half blue over red is a little bluer than half.
        let alpha = 128.0 / 255
        let red = compositing == .linear ? TransferFunction.sRGB.encode(1 - alpha) : 1 - alpha
        let blue = compositing == .linear ? TransferFunction.sRGB.encode(alpha) : alpha
        #expect(abs(red - expected) < 0.004)
        #expect(abs(pixel[0] - red) < 0.002 && abs(pixel[1]) < 0.002 && abs(pixel[2] - blue) < 0.002, "\(pixel)")
        #expect(abs(pixel[3] - 1) < 0.001)
    }

    // MARK: - Private
    private func list(
        backdrop: String,
        source: String,
        mode: BlendMode,
        compositing: Compositing
    ) -> DisplayList {
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 4, height: 4), color: Color(written: source))

        return DisplayList(
            size: Size(width: 4, height: 4),
            background: Color(written: backdrop),
            compositing: compositing,
            seed: 0,
            items: [DisplayItem(blend: mode.rawValue, content: .path(fill))]
        )
    }

    private func components(of written: String) -> [Double] {
        let color = Color(written: written)

        return [color.red, color.green, color.blue, color.alpha]
    }
}
