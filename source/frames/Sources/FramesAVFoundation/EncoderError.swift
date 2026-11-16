//
//  EncoderError.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import Frames

package enum EncoderError: Error, Equatable, CustomStringConvertible, Sendable {
    case unencodable(file: String, codec: String)
    case unwritable(file: String, reason: String)
    case frameSize(file: String, index: Int, size: Size, video: Size)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .unencodable(file, codec):
            "encoder avfoundation cannot write \(file): this machine has no \(codec) encoder"

        case let .unwritable(file, reason):
            "encoder avfoundation cannot write \(file): \(reason)"

        case let .frameSize(file, index, size, video):
            "frame \(index) of \(file) is \(written(size)), where the video is \(written(video))"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func written(_ size: Size) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }
}
