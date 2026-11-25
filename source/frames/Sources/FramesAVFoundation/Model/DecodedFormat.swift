//
//  DecodedFormat.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/26/26.
//

import CoreVideo

// How AVAssetReader gives the decoder a video's frames (FRAMES-21 Rules): in the Y'CbCr its stream stores, which the
// decoder takes to R'G'B' itself, or as R'G'B' half floats VideoToolbox converted them to.
enum DecodedFormat: Equatable, Sendable {
    case yCbCr(YCbCrLayout)
    case halfFloatRGBA

    // MARK: - Property
    var pixelFormat: OSType {
        switch self {
        case let .yCbCr(layout):
            layout.pixelFormat

        case .halfFloatRGBA:
            kCVPixelFormatType_64RGBAHalf
        }
    }

    // As FRAMES-23 Runs names a pixel format.
    var name: String {
        switch self {
        case let .yCbCr(layout):
            layout.name

        case .halfFloatRGBA:
            "16-bit float RGBA"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
