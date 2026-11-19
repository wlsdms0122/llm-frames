//
//  ToneMappingTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

@testable import Frames
import Testing

@Suite("ToneMapping Tests")
struct ToneMappingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    // At a source peak of 1000 cd/m²: PQ(1000) = 0.7518271, PQ(500) = 0.6765848, so E1 = 0.8999208; maxLum =
    // PQ(203) / PQ(1000) = 0.7723702, KS = 1.5 × maxLum - 0.5 = 0.6585554, T = (E1 - KS) / (1 - KS) = 0.7068947, and
    // the spline gives E2 = 0.7695043, so M' = EOTF(E2 × PQ(1000)) = 198.856 cd/m².
    @Test("500 cd/m² from a 1000 cd/m² source maps by the BT.2390 knee to 198.856 cd/m²")
    func mapsAboveKnee() {
        // Given
        let sut = ToneMapping(sourcePeak: 1000, targetPeak: 203)
        let light = RGB(red: 500, green: 500, blue: 500)

        // When
        let mapped = sut.mapped(light)

        // Then
        #expect(abs(mapped.green - 198.85600894863137) < 1e-6)
    }

    @Test(
        "light below the knee is kept and the source peak maps to the target peak",
        arguments: [(50.0, 50.0), (1000.0, 203.0), (5000.0, 203.0)]
    )
    func keepsBelowKneeAndMapsPeak(
        light: Double,
        expected: Double
    ) {
        // Given
        let sut = ToneMapping(sourcePeak: 1000, targetPeak: 203)

        // When
        let mapped = sut.mapped(RGB(red: light, green: light, blue: light))

        // Then
        #expect(abs(mapped.red - expected) < 1e-6)
    }

    @Test("the hue is kept by scaling every channel by the ratio of max(R, G, B)")
    func keepsHue() {
        // Given
        let sut = ToneMapping(sourcePeak: 1000, targetPeak: 203)
        let light = RGB(red: 500, green: 250, blue: 50)

        // When
        let mapped = sut.mapped(light)

        // Then
        #expect(abs(mapped.red - 198.85600894863137) < 1e-6)
        #expect(abs(mapped.green / mapped.red - 0.5) < 1e-12)
        #expect(abs(mapped.blue / mapped.red - 0.1) < 1e-12)
    }

    @Test(
        "the source peak is the mastering display's for PQ, 1000 cd/m² without one, and 1000 cd/m² for HLG",
        arguments: [
            (ColorSpace.rec2100PQ, Optional(4000.0), 4000.0),
            (.rec2100PQ, nil, 1000),
            (.rec2100PQ, 20000, 10000),
            (.rec2100HLG, 4000, 1000)
        ]
    )
    func takesSourcePeak(
        space: ColorSpace,
        masteringDisplayPeak: Double?,
        expected: Double
    ) {
        // Given
        let peak = masteringDisplayPeak

        // When
        let sut = ToneMapping(space: space, masteringDisplayPeak: peak, targetPeak: 203)

        // Then
        #expect(sut.sourcePeak == expected)
    }

    @Test(
        "an HDR target peak maps a brighter source's peak to it and keeps a source at or below it",
        arguments: [(10000.0, 10000.0, 1000.0), (1000.0, 1000.0, 1000.0), (1000.0, 600.0, 600.0)]
    )
    func mapsToHDRTarget(
        sourcePeak: Double,
        light: Double,
        expected: Double
    ) {
        // Given
        let sut = ToneMapping(sourcePeak: sourcePeak, targetPeak: 1000)

        // When
        let mapped = sut.mapped(RGB(red: light, green: light, blue: light))

        // Then
        #expect(abs(mapped.red - expected) < 1e-6)
    }

    @Test(
        "each colour space's peak: reference white for SDR, 1000 cd/m² for HLG and 10000 cd/m² for PQ",
        arguments: [
            (ColorSpace.srgb, 203.0), (.displayP3, 203), (.rec2020, 203), (.rec709, 203), (.rec2100HLG, 1000),
            (.rec2100PQ, 10000)
        ]
    )
    func givesPeak(
        space: ColorSpace,
        expected: Double
    ) {
        // When, Then
        #expect(space.peakLuminance == expected)
    }
}
