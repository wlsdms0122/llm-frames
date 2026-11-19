//
//  ColorWrittenTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

@testable import Frames
import Testing

@Suite("Color Written Tests")
struct ColorWrittenTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a hex colour is the encoded working value of its digits over 255, of either case, alpha 1 when it has six",
        arguments: [
            ("#FF8000", [1, 128.0 / 255, 0, 1]),
            ("#ff800080", [1, 128.0 / 255, 0, 128.0 / 255]),
            ("#00000000", [0, 0, 0, 0])
        ] as [(String, [Double])]
    )
    func readsHex(
        written: String,
        expected: [Double]
    ) throws {
        // When
        let color = try #require(Color(parsing: written))

        // Then
        #expect(channels(of: color) == expected)
    }

    // The expected values are the matrices of FRAMES-26 to ten places applied to a red of 1, encoded by the extended
    // sRGB transfer; the BT.1886 decode of 1 is 1.
    @Test(
        "a color() value is converted from its space, srgb as written and srgb-linear by the extended sRGB transfer",
        arguments: [
            ("color(srgb 0.25 -0.5 2)", [0.25, -0.5, 2, 1]),
            ("color(srgb-linear 2 2 2 / 0.5)", [1.3532560461493863, 1.3532560461493863, 1.3532560461493863, 0.5]),
            ("color(display-p3 1 0 0)", [1.0930663624427532, -0.2267419735427118, -0.15013458097918908, 1]),
            ("color(rec2020 1 0 0)", [1.2482198281890042, -0.3879075028611894, -0.14351439270878863, 1]),
            ("color(  srgb   1 0 0/0.25  )", [1, 0, 0, 0.25]),
            ("color(srgb 1 0 0 / 0)", [1, 0, 0, 0])
        ] as [(String, [Double])]
    )
    func readsFunction(
        written: String,
        expected: [Double]
    ) {
        // When
        let color = Color(parsing: written)

        // Then
        let read = color.map(channels) ?? []
        #expect(read.count == 4 && zip(read, expected).allSatisfy { abs($0 - $1) < 1e-9 }, "\(read)")
    }

    @Test("a signed number with a fraction and an exponent is a number of the grammar")
    func readsNumberForm() {
        // When
        let color = Color(parsing: "color(srgb +.5e+1 -1E-1 0.25)")

        // Then
        #expect(color == Color(red: 5, green: -0.1, blue: 0.25, alpha: 1))
    }

    @Test(
        "a string that does not match the grammar, a component that is not finite or an alpha outside 0 to 1 is no colour",
        arguments: [
            "#FFF", "#FF00000", "#GG0000", "#\u{FF26}\u{FF26}0000", "FF0000",
            "color(srgb 1 0)", "color(srgb 1 0 0 0)", "color(xyz 1 0 0)", "color(SRGB 1 0 0)", "COLOR(srgb 1 0 0)",
            "color(srgb,1,0,0)", "color(srgb 1 0 0", "color(srgb 1 0 0) ", "color(srgb1 0 0)", "color(srgb 50% 0 0)",
            "color(srgb 1. 0 0)", "color(srgb 1 0 0 /)", "color(srgb 1 0 0 / 0.5 / 1)", "color(srgb 1 0 0 / 1.5)",
            "color(srgb 1 0 0 / -0.1)", "color(srgb 1e999 0 0)", "color(srgb nan 0 0)", "color(srgb inf 0 0)",
            "color(srgb 0x1 0 0)", "color(srgb 1\t0 0)"
        ]
    )
    func refusesMalformed(written: String) {
        // When, Then
        #expect(Color(parsing: written) == nil)
    }

    @Test("the resolved form is color(srgb r g b / a) with its numbers in the number form of FRAMES-19, alpha always written")
    func writesResolvedForm() {
        // Given
        let colors = [
            Color(red: 0.25, green: -0.5, blue: 2, alpha: 1),
            Color(written: "#1B3A6B"),
            Color(written: "color(display-p3 1 0 0 / 0.5)")
        ]

        // When
        let written = colors.map(\.resolvedForm)

        // Then
        #expect(written[0] == "color(srgb 0.25 -0.5 2 / 1)")
        #expect(written[1] == "color(srgb 0.10588235294117647 0.22745098039215686 0.4196078431372549 / 1)")
        #expect(colors.map { Color(resolvedForm: $0.resolvedForm) } == colors)
    }

    @Test(
        "a resolved colour of any other form is not read",
        arguments: [
            "#FFFFFFFF", "color(srgb 1 1 1)", "color(srgb  1 1 1 / 1)", "color(srgb 1 1 1/1)", "color(display-p3 1 1 1 / 1)",
            "color(srgb 1 1 1 / 2)", "color(srgb-linear 1 1 1 / 1)"
        ]
    )
    func refusesOtherResolvedForms(written: String) {
        // When, Then
        #expect(Color(resolvedForm: written) == nil)
    }

    @Test("a keyframed colour mixes on the encoded form and an overshoot is held to min(0, a, b) to max(1, a, b)")
    func interpolatesHeld() {
        // Given
        let start = Color(red: 0, green: 0.5, blue: 2, alpha: 0)
        let end = Color(red: 1, green: -1, blue: 1.5, alpha: 1)

        // When
        let middle = Color.interpolate(from: start, to: end, progress: 0.5)
        let overshot = Color.interpolate(from: start, to: end, progress: 1.5)
        let undershot = Color.interpolate(from: start, to: end, progress: -0.5)

        // Then
        #expect(middle == Color(red: 0.5, green: -0.25, blue: 1.75, alpha: 0.5))
        #expect(overshot == Color(red: 1, green: -1, blue: 1.25, alpha: 1))
        #expect(undershot == Color(red: 0, green: 1, blue: 2, alpha: 0))
    }

    // MARK: - Private
    private func channels(of color: Color) -> [Double] {
        [color.red, color.green, color.blue, color.alpha]
    }
}
