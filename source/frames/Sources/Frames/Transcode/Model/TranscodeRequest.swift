//
//  TranscodeRequest.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// One transcode: the file to read, the file to write, how hard to shrink it, the cap on a picture's longer side, the
// codec of a video output, H.264 in an SDR colour space and HEVC in an HDR one when none is given, and the colour space
// of a picture output, the source's when none is given.
package struct TranscodeRequest: Equatable, Sendable {
    // MARK: - Property
    package let input: String
    package let output: String
    package let quality: EncodeQuality
    package let maximumSide: Int?
    package let codec: VideoCodec?
    package let colorSpace: ColorSpace?

    var outputExtension: String {
        URL(fileURLWithPath: output).pathExtension.lowercased()
    }

    // MARK: - Initializer
    package init(
        input: String,
        output: String,
        quality: EncodeQuality = .medium,
        maximumSide: Int? = nil,
        codec: VideoCodec? = nil,
        colorSpace: ColorSpace? = nil
    ) {
        self.input = input
        self.output = output
        self.quality = quality
        self.maximumSide = maximumSide
        self.codec = codec
        self.colorSpace = colorSpace
    }

    // MARK: - Public
    // MARK: - Private
}
