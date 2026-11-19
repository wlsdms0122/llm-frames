//
//  ImageTarget.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// An image file an encoder writes from one bitmap, scaled to `size`, encoded and tagged by `output`, the colour space and
// peak of the sequence or transcode it writes (FRAMES-26). A PNG is lossless at `depth`, eight or sixteen bits per
// channel. A JPEG or HEIC is written at its quality's `imageQuality`, a HEIC at 10 bits per channel in an HDR colour
// space and 8 in an SDR one, and a JPEG, which holds 8 bits and no alpha, only in an SDR colour space, its transparent
// parts on white.
package enum ImageTarget: Equatable, Sendable {
    case png(path: String, size: Size, depth: BitDepth = .eight, output: ColorConversion = ColorConversion(space: .srgb))
    case jpeg(path: String, size: Size, quality: EncodeQuality, output: ColorConversion = ColorConversion(space: .srgb))
    case heic(path: String, size: Size, quality: EncodeQuality, output: ColorConversion = ColorConversion(space: .srgb))

    // MARK: - Property
    package var path: String {
        switch self {
        case let .png(path, _, _, _), let .jpeg(path, _, _, _), let .heic(path, _, _, _):
            path
        }
    }

    package var size: Size {
        switch self {
        case let .png(_, size, _, _), let .jpeg(_, size, _, _), let .heic(_, size, _, _):
            size
        }
    }

    package var output: ColorConversion {
        switch self {
        case let .png(_, _, _, output), let .jpeg(_, _, _, output), let .heic(_, _, _, output):
            output
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
