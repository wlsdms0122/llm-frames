//
//  ChannelGain.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Factors that multiply linear light channel by channel.
package struct ChannelGain: Equatable, Sendable {
    // MARK: - Property
    package let red: Double
    package let green: Double
    package let blue: Double

    // MARK: - Initializer
    package init(
        red: Double,
        green: Double,
        blue: Double
    ) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    // The `temperature` operation's gain: a blackbody at 6500 - `kelvin` K over one at 6500 K, each in linear sRGB at
    // equal luminance, with the temperature kept between 1000 and 40000 K.
    package init(kelvin: Double) {
        let temperature = min(max(6500 - kelvin, 1000), 40000)
        let shifted = LinearRGB(xyz: Blackbody(temperature: temperature).xyz())
        let reference = LinearRGB(xyz: Blackbody(temperature: 6500).xyz())

        self.init(
            red: shifted.red / reference.red,
            green: shifted.green / reference.green,
            blue: shifted.blue / reference.blue
        )
    }

    // MARK: - Public
    // MARK: - Private
}
