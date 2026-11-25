//
//  FileEncoding.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How an encoder wrote one file (FRAMES-23 Runs): the codec its pictures are written as, whether a hardware encoder
// wrote them, the processor that took its frames to the output's values, and its seconds in `outputConversion` and
// `encode`.
package struct FileEncoding: Equatable, Sendable {
    // MARK: - Property
    package let path: String
    package let codec: String
    package let usesHardware: Bool
    package let device: ConversionDevice
    package let seconds: StageTimes

    // MARK: - Initializer
    package init(
        path: String,
        codec: String,
        usesHardware: Bool,
        device: ConversionDevice,
        seconds: StageTimes
    ) {
        self.path = path
        self.codec = codec
        self.usesHardware = usesHardware
        self.device = device
        self.seconds = seconds
    }

    // MARK: - Public
    // MARK: - Private
}
