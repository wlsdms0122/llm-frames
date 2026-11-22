//
//  PageFault.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Frames

// What keeps the decoder from reading a page of a PDF (FRAMES-3 PDF pages): a `Rotate` that is not a multiple of 90, a
// size under 1 media pixel on a side, drawn text set in a font the file does not embed, and a `colorSpace` other than
// `srgb` for the untagged colour of a page that draws in other colour spaces too. Core Graphics draws DeviceRGB and
// DeviceGray as sRGB into every space, so the decoder reads untagged colour in another space by taking the drawn sRGB
// numbers in that space, which holds only where no tagged colour is drawn.
package enum PageFault: Error, Equatable, Sendable {
    case rotation(Int)
    case size(Size)
    case unembeddedFont(String)
    case untaggedColor(ColorSpace)

    // MARK: - Property
    var reason: String {
        switch self {
        case let .rotation(angle):
            "its Rotate \(angle) is not a multiple of 90"

        case let .size(size):
            "its size \(size.width)x\(size.height) is under 1 point on a side"

        case let .unembeddedFont(font):
            "it sets text in the font \(font), which the file does not embed"

        case let .untaggedColor(colorSpace):
            "it draws in tagged colour spaces besides its untagged colour, which this decoder reads in "
                + "\(colorSpace.rawValue) only on a page that draws in no other colour space, since Core Graphics draws "
                + "DeviceRGB and DeviceGray as sRGB whatever space it draws into, and in one picture they cannot be told "
                + "from the tagged colour"
        }
    }

    // Whether `transcode`, or a program that embeds the file's fonts, gives a file the decoder reads.
    var suggestsConversion: Bool {
        switch self {
        case .unembeddedFont:
            true

        case .rotation, .size, .untaggedColor:
            false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
