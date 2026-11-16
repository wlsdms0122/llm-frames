//
//  ChannelGainTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames
import Testing

@Suite("ChannelGain Tests")
struct ChannelGainTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a temperature of 0 kelvin leaves every channel as it is")
    func leavesChannelsAtZero() {
        // Given
        let kelvin = 0.0

        // When
        let sut = ChannelGain(kelvin: kelvin)

        // Then
        #expect(sut == ChannelGain(red: 1, green: 1, blue: 1))
    }

    @Test(
        "a positive temperature raises red over blue, and a negative one blue over red",
        arguments: [500.0, 2000.0, 5000.0]
    )
    func warmsWithPositiveKelvin(kelvin: Double) {
        // Given
        let warm = kelvin
        let cool = -kelvin

        // When
        let warmer = ChannelGain(kelvin: warm)
        let cooler = ChannelGain(kelvin: cool)

        // Then
        #expect(warmer.red > 1)
        #expect(warmer.blue < 1)
        #expect(cooler.blue > 1)
        #expect(cooler.red < 1)
    }

    @Test(
        "the blackbody's temperature is kept between 1000 and 40000 K",
        arguments: [
            (5500.0, 9000.0),
            (-33500.0, -60000.0)
        ]
    )
    func keepsTemperatureInRange(
        atBound: Double,
        beyond: Double
    ) {
        // Given
        let bound = ChannelGain(kelvin: atBound)

        // When
        let sut = ChannelGain(kelvin: beyond)

        // Then
        #expect(sut == bound)
    }

    @Test("the gain is the shifted blackbody over the 6500 K one, each in linear sRGB at a luminance of 1")
    func scalesToEqualLuminance() {
        // Given
        let reference = LinearRGB(xyz: Blackbody(temperature: 6500).xyz())
        let shifted = LinearRGB(xyz: Blackbody(temperature: 3500).xyz())

        // When
        let sut = ChannelGain(kelvin: 3000)

        // Then
        #expect(abs(sut.red * reference.red - shifted.red) < 1e-12)
        #expect(abs(sut.green * reference.green - shifted.green) < 1e-12)
        #expect(abs(sut.blue * reference.blue - shifted.blue) < 1e-12)
        #expect(abs(luminance(shifted) - 1) < 1e-3)
        #expect(abs(luminance(reference) - 1) < 1e-3)
    }

    // MARK: - Private
    // Rec. 709 luminance of linear sRGB, the Y row of the sRGB to XYZ matrix.
    private func luminance(_ color: LinearRGB) -> Double {
        0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
    }
}
