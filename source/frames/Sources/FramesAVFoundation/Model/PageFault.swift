//
//  PageFault.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Frames

// What keeps the decoder from reading a page of a PDF (FRAMES-3 PDF pages): a `Rotate` that is not a multiple of 90, a
// size under 1 media pixel on a side, content held in another file, drawn text set in a font the file does not embed,
// a colour space the decoder does not convert by the formulas of FRAMES-26 Media, and a `colorSpace` other than `srgb`
// for the untagged colour of a page that draws in other colour spaces too, which this decoder does not read.
package enum PageFault: Error, Equatable, Sendable {
    case rotation(Int)
    case size(Size)
    case externalContent(String)
    case unembeddedFont(String)
    case colorSpace(String)
    case untaggedColor(ColorSpace)

    // MARK: - Property
    var reason: String {
        switch self {
        case let .rotation(angle):
            "its Rotate \(angle) is not a multiple of 90"

        case let .size(size):
            "its size \(size.width)x\(size.height) is under 1 point on a side"

        case let .externalContent(content):
            "it draws \(content), which another file holds"

        case let .unembeddedFont(font):
            "it sets text in the font \(font), which the file does not embed"

        case let .colorSpace(space):
            "it draws in \(space), which this decoder does not convert by the fixed formulas"

        case let .untaggedColor(colorSpace):
            "this decoder reads its untagged colour in \(colorSpace.rawValue) only on a page that draws in no other "
                + "colour space"
        }
    }

    // Whether `transcode`, or a program that converts the file, gives a file the decoder reads.
    var suggestsConversion: Bool {
        switch self {
        case .unembeddedFont, .colorSpace:
            true

        case .rotation, .size, .externalContent, .untaggedColor:
            false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
