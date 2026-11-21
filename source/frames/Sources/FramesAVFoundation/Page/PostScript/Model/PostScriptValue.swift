//
//  PostScriptValue.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// An operand of a PostScript calculator function (ISO 32000-1 7.10.5): an integer, a real or a boolean.
enum PostScriptValue: Equatable, Sendable {
    case integer(Int)
    case real(Double)
    case boolean(Bool)

    // MARK: - Property
    // The value as a number, nil for a boolean.
    var number: Double? {
        switch self {
        case let .integer(value):
            Double(value)

        case let .real(value):
            value

        case .boolean:
            nil
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
