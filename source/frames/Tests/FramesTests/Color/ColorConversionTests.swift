//
//  ColorConversionTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

@testable import Frames
import Testing

@Suite("ColorConversion Tests")
struct ColorConversionTests {
    // MARK: - Property
    private static let white = RGB(red: 1, green: 1, blue: 1)

    // MARK: - Initializer
    // MARK: - Test
    @Test("the red of P3 is about 1.0931 -0.2268 -0.1501 in extended sRGB")
    func readsDisplayP3Red() {
        // Given
        let sut = ColorConversion(space: .displayP3)

        // When
        let working = sut.working(RGB(red: 1, green: 0, blue: 0))

        // Then
        #expect(abs(working.red - 1.0930663624351615) < 1e-9)
        #expect(abs(working.green - -0.22674197356975406) < 1e-9)
        #expect(abs(working.blue - -0.1501345809371196) < 1e-9)
    }

    @Test("sRGB white is 0.5806 in PQ, at 203 cd/m²")
    func encodesWhiteInPQ() {
        // Given
        let sut = ColorConversion(space: .rec2100PQ)

        // When
        let encoded = sut.encoded(Self.white)

        // Then
        #expect(abs(encoded.red - 0.5806888810416109) < 1e-9)
        #expect(abs(encoded.green - 0.5806888810416109) < 1e-9)
        #expect(abs(encoded.blue - 0.5806888810416109) < 1e-9)
    }

    @Test("sRGB white is 0.75 in HLG, as BT.2408 gives it")
    func encodesWhiteInHLG() {
        // Given
        let sut = ColorConversion(space: .rec2100HLG)

        // When
        let encoded = sut.encoded(Self.white)

        // Then
        #expect(abs(encoded.green - 0.75) < 1e-3)
    }

    @Test(
        "a working value converted to a space and back is the same value",
        arguments: ColorSpace.allCases,
        [RGB(red: 0.2, green: 0.5, blue: 0.8), RGB(red: 1, green: 1, blue: 1), RGB(red: 0.9, green: 0.1, blue: 0.4)]
    )
    func roundTrips(
        space: ColorSpace,
        working: RGB
    ) {
        // Given
        let sut = ColorConversion(space: space)

        // When
        let back = sut.working(sut.encoded(working))

        // Then
        #expect(abs(back.red - working.red) < 1e-9)
        #expect(abs(back.green - working.green) < 1e-9)
        #expect(abs(back.blue - working.blue) < 1e-9)
    }

    @Test("a wide gamut and HDR working value survives an SDR space unclipped, and the output clips it")
    func keepsWideGamutUntilOutput() {
        // Given
        let sut = ColorConversion(space: .rec2020)
        let working = RGB(red: 1.5, green: -0.1, blue: 0.3)

        // When
        let back = sut.working(sut.encoded(working))
        let output = sut.output(working)

        // Then
        #expect(abs(back.red - 1.5) < 1e-9)
        #expect(abs(back.green - -0.1) < 1e-9)
        #expect([output.red, output.green, output.blue].allSatisfy { (0...1).contains($0) })
    }

    @Test("an srgb output is each channel clipped to 0 to 1")
    func clipsSRGBOutput() {
        // Given
        let sut = ColorConversion(space: .srgb)

        // When
        let output = sut.output(RGB(red: 1.2, green: -0.3, blue: 0.4))

        // Then
        #expect(output == RGB(red: 1, green: 0, blue: 0.4))
    }

    @Test("HDR display light is clipped to the space's peak", arguments: [ColorSpace.rec2100PQ, .rec2100HLG])
    func clipsHDRToPeak(space: ColorSpace) {
        // Given
        let sut = ColorConversion(space: space)
        let bright = RGB(red: 1000, green: 1000, blue: 1000)

        // When
        let light = sut.displayLight(sut.encoded(bright))

        // Then
        #expect(abs(light.green - (space.peakLuminance ?? 0)) < 1e-6)
    }

    @Test("a tone mapped HLG reference white stays below SDR white and keeps grey")
    func toneMapsHLG() {
        // Given
        let sut = ColorConversion(space: .rec2100HLG)
        let mapping = ToneMapping(space: .rec2100HLG, masteringDisplayPeak: nil)

        // When
        let working = sut.toneMapped(RGB(red: 0.75, green: 0.75, blue: 0.75), by: mapping)

        // Then
        #expect(working.red < 1)
        #expect(working.red > 0.8)
        #expect(abs(working.green - working.red) < 1e-9)
        #expect(abs(working.blue - working.red) < 1e-9)
    }

    @Test("a video tagged with the table's code points is in its space, and an untagged one is srgb")
    func readsCodePoints() {
        // Given
        let tagged = ColorSpace.allCases.map(\.codePoints)

        // When
        let spaces = tagged.map { points in
            ColorSpace(colorPrimaries: points.colorPrimaries, transferCharacteristics: points.transferCharacteristics)
        }
        let untagged = ColorSpace(colorPrimaries: nil, transferCharacteristics: 2)
        let outside = ColorSpace(colorPrimaries: 9, transferCharacteristics: 13)

        // Then
        #expect(spaces == ColorSpace.allCases)
        #expect(untagged == .srgb)
        #expect(outside == nil)
    }

    @Test("a pixel buffer is converted unpremultiplied and a transparent pixel stays 0")
    func convertsPremultipliedPixels() {
        // Given
        var pixels: [Float] = [0.25, 0.25, 0.25, 0.5, 0.3, 0.3, 0.3, 0]

        // When
        pixels.withUnsafeMutableBufferPointer { buffer in
            buffer.convertColors { $0.scaled(by: 2) }
        }

        // Then
        #expect(pixels == [0.5, 0.5, 0.5, 0.5, 0, 0, 0, 0])
    }
}
