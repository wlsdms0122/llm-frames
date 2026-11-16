//
//  TestMediaError.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/16/26.
//

enum TestMediaError: Error, Equatable, CustomStringConvertible, Sendable {
    case unwritable(String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .unwritable(path):
            "test media \(path) could not be written"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
