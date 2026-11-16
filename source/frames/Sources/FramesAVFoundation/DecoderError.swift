//
//  DecoderError.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

package enum DecoderError: Error, Equatable, CustomStringConvertible, Sendable {
    case unreadable(file: String)
    case noFrame(file: String, index: Int, count: Int)
    case frameCount(file: String, pinned: Int, counted: Int)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .unreadable(file):
            "media \(file) cannot be read"

        case let .noFrame(file, index, count):
            "media \(file) has no frame \(index): it has \(count)"

        case let .frameCount(file, pinned, counted):
            "media \(file) has \(counted) frames where the resolved document pins \(pinned). Resolve it again"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
