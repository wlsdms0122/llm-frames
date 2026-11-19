//
//  TranscodeRequest.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// One transcode: the file to read, the file to write, how hard to shrink it, the cap on a picture's longer side, and
// the codec of a video output, H.264 when none is given.
package struct TranscodeRequest: Equatable, Sendable {
    // MARK: - Property
    package let input: String
    package let output: String
    package let quality: EncodeQuality
    package let maximumSide: Int?
    package let codec: VideoCodec?

    var outputExtension: String {
        URL(fileURLWithPath: output).pathExtension.lowercased()
    }

    // MARK: - Initializer
    package init(
        input: String,
        output: String,
        quality: EncodeQuality = .medium,
        maximumSide: Int? = nil,
        codec: VideoCodec? = nil
    ) {
        self.input = input
        self.output = output
        self.quality = quality
        self.maximumSide = maximumSide
        self.codec = codec
    }

    // MARK: - Public
    // MARK: - Private
}
