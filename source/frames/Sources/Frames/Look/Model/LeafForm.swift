//
//  LeafForm.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The form a leaf's value takes. Numbers, colours and fixed-length number lists are timed; names, booleans, files and
// static numbers, which decide faces, shaping or line breaks, are static.
enum LeafForm: Equatable, Sendable {
    case number
    case color
    case numbers(count: Int)
    case name
    case boolean
    case file
    case staticNumber

    // MARK: - Property
    var isTimed: Bool {
        switch self {
        case .number, .color, .numbers:
            true

        case .name, .boolean, .file, .staticNumber:
            false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
