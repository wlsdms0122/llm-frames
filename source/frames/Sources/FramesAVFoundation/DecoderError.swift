//
//  DecoderError.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import Frames

package enum DecoderError: Error, Equatable, CustomStringConvertible, Sendable {
    case unreadable(file: String)
    case unloadable(file: String, reason: String)
    case emptySequence(directory: String)
    case unequalFrame(file: String, size: Size, first: Size)
    case noFrame(file: String, index: Int, count: Int)
    case frameCount(file: String, pinned: Int, counted: Int)
    case noSound(file: String)
    case unconvertibleColor(file: String, reason: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .unreadable(file):
            "media \(file) cannot be read"

        case let .unloadable(file, reason):
            "media \(file) cannot be read: \(reason)"

        case let .emptySequence(directory):
            "image sequence \(directory) holds no PNG frames"

        case let .unequalFrame(file, size, first):
            "image sequence frame \(file) is \(written(size)), where the first frame is \(written(first))"

        case let .noFrame(file, index, count):
            "media \(file) has no frame \(index): it has \(count)"

        case let .frameCount(file, pinned, counted):
            "media \(file) has \(counted) frames where the resolved document pins \(pinned). Resolve it again"

        case let .noSound(file):
            "media \(file) has no sound track"

        case let .unconvertibleColor(file, reason):
            "media \(file) cannot be read: \(reason), which no fixed formula converts. Write the colorSpace it is in "
                + "where it is named, or convert it with transcode"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func written(_ size: Size) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }
}
