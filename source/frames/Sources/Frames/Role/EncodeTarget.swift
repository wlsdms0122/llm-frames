//
//  EncodeTarget.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// A video file an encoder writes, its frames encoded and tagged by `output`, the colour space and peak of the sequence
// or transcode it writes (FRAMES-26). A master is ProRes 422 HQ, or ProRes 4444 with `alpha`, with 24-bit PCM sound at
// 48 kHz in stereo. A delivery is H.264 for an SDR colour space and HEVC Main 10 for an HDR one, at the encoder's
// highest quality with AAC at 256 kbps, its transparent parts over black. A compressed video is `codec` at `quality`,
// HEVC at Main 10 in an HDR colour space, its frames scaled to `size` and their transparent parts over black, with its
// sound as a sound target of the same quality writes it.
package enum EncodeTarget: Equatable, Sendable {
    case master(path: String, alpha: Bool, output: ColorConversion = ColorConversion(space: .srgb))
    case delivery(path: String, output: ColorConversion = ColorConversion(space: .srgb))
    case compressed(
        path: String,
        codec: VideoCodec,
        quality: EncodeQuality,
        size: Size,
        output: ColorConversion = ColorConversion(space: .srgb)
    )

    // MARK: - Property
    package var path: String {
        switch self {
        case let .master(path, _, _), let .delivery(path, _), let .compressed(path, _, _, _, _):
            path
        }
    }

    package var output: ColorConversion {
        switch self {
        case let .master(_, _, output), let .delivery(_, output), let .compressed(_, _, _, _, output):
            output
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
