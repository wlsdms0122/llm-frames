//
//  JSONError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum JSONError: Error, Equatable, CustomStringConvertible, Sendable {
    case syntax(line: Int, column: Int, reason: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .syntax(line, column, reason):
            "line \(line), column \(column): \(reason)"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
