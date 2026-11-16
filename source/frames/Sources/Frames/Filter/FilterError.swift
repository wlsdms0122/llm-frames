//
//  FilterError.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

package enum FilterError: Error, Equatable, CustomStringConvertible, Sendable {
    case malformedCube(file: String, line: Int, reason: String)
    case unreadableCube(file: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .malformedCube(file, line, reason):
            "\(file): line \(line): \(reason)"

        case let .unreadableCube(file):
            "\(file): the LUT cannot be read as UTF-8 text"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
