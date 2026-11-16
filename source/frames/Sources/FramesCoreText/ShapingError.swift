//
//  ShapingError.swift
//  FramesCoreText
//
//  Created by JSilver on 11/16/26.
//

package enum ShapingError: Error, Equatable, CustomStringConvertible, Sendable {
    case faceNotInFile(file: String, name: String)
    case fallbackWithoutFile(name: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .faceNotInFile(file, name):
            "font file \(file) holds no face \(name)"

        case let .fallbackWithoutFile(name):
            "the fallback face \(name) has no font file to name"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
