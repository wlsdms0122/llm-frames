//
//  VisionError.swift
//  FramesVision
//
//  Created by JSilver on 11/16/26.
//

package enum VisionError: Error, Equatable, CustomStringConvertible, Sendable {
    case unreadablePicture(file: String, index: Int)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .unreadablePicture(file, index):
            "frame \(index) of media \(file) cannot be given to Vision"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
