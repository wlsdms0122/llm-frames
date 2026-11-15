//
//  JSONError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `file` names a file other than the document, as it was referred to.
enum JSONError: Error, Equatable, CustomStringConvertible, Sendable {
    case syntax(file: String? = nil, line: Int, column: Int, reason: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .syntax(file, line, column, reason):
            (file.map { "\($0): " } ?? "") + "line \(line), column \(column): \(reason)"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
