//
//  PictureReading.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// How the decoder reads a picture (FRAMES-21). `working` reads working values: in `colorSpace`, written where the
// media is named, over what the file's tags say, and an HDR picture tone mapped to `targetPeak` in cd/m² where its
// source peak is above it, or taken as display light where `targetPeak` is nil. `analysis` reads an analysis picture
// (FRAMES-26 Providers and analysis pictures): SDR sRGB, each channel from 0 to 1, read in `colorSpace` where one is
// written. `platform` reads working values by the platform's own colour management at relative intent into
// `colorSpace`, then by that space's formulas: the one reading of a picture no fixed formula converts, which
// `transcode` makes (FRAMES-23).
package enum PictureReading: Equatable, Sendable {
    case working(colorSpace: ColorSpace?, targetPeak: Double?)
    case analysis(colorSpace: ColorSpace?)
    case platform(colorSpace: ColorSpace)

    // MARK: - Property
    // The working values of the file as its tags say, with no tone mapping.
    package static let tagged = PictureReading.working(colorSpace: nil, targetPeak: nil)

    package var colorSpace: ColorSpace? {
        switch self {
        case let .working(colorSpace, _), let .analysis(colorSpace):
            colorSpace

        case let .platform(colorSpace):
            colorSpace
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
