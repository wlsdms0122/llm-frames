//
//  HighDynamicRangeTransferTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

@testable import Frames
import Testing

@Suite("High Dynamic Range Transfer Tests")
struct HighDynamicRangeTransferTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("PQ encodes the BT.2408 reference white of 203 cd/m² to 0.5806")
    func encodesReferenceWhiteInPQ() {
        // Given
        let sut = PerceptualQuantizer()

        // When
        let encoded = sut.encoded(displayLight: 203)

        // Then
        #expect(abs(encoded - 0.5806888810416109) < 1e-12)
    }

    @Test("the PQ EOTF gives the light back", arguments: [0.0, 0.1, 50, 203, 1000, 10000])
    func roundTripsPQ(light: Double) {
        // Given
        let sut = PerceptualQuantizer()

        // When
        let decoded = sut.displayLight(encoded: sut.encoded(displayLight: light))

        // Then
        #expect(abs(decoded - light) < 1e-9 * max(light, 1))
    }

    @Test("PQ clips an encoded value outside 0 to 1 so it names finite light")
    func clipsPQ() {
        // Given
        let sut = PerceptualQuantizer()

        // When
        let above = sut.displayLight(encoded: 1.5)
        let below = sut.displayLight(encoded: -0.2)

        // Then
        #expect(abs(above - 10000) < 1e-9)
        #expect(below == 0)
    }

    @Test("HLG grey at 0.75 is about 203 cd/m² with its OOTF at 1000 cd/m²")
    func decodesHLGReferenceWhite() {
        // Given
        let sut = HybridLogGamma()
        let grey = RGB(red: 0.75, green: 0.75, blue: 0.75)

        // When
        let light = sut.displayLight(encoded: grey)

        // Then
        #expect(abs(light.green - 203.15214593754538) < 1e-9)
        #expect(abs(light.red - light.green) < 1e-9)
    }

    @Test(
        "the HLG OETF of the inverse OOTF gives the encoded value back",
        arguments: [
            RGB(red: 0.75, green: 0.75, blue: 0.75),
            RGB(red: 0.9, green: 0.3, blue: 0.1),
            RGB(red: 0.2, green: 0.4, blue: 0.6)
        ]
    )
    func roundTripsHLG(encoded: RGB) {
        // Given
        let sut = HybridLogGamma()

        // When
        let back = sut.encoded(displayLight: sut.displayLight(encoded: encoded))

        // Then
        #expect(abs(back.red - encoded.red) < 1e-9)
        #expect(abs(back.green - encoded.green) < 1e-9)
        #expect(abs(back.blue - encoded.blue) < 1e-9)
    }

    @Test("HLG gives black for black, both ways")
    func keepsBlackInHLG() {
        // Given
        let sut = HybridLogGamma()
        let black = RGB(red: 0, green: 0, blue: 0)

        // When
        let light = sut.displayLight(encoded: black)
        let encoded = sut.encoded(displayLight: black)

        // Then
        #expect(light == black)
        #expect(encoded == black)
    }
}
