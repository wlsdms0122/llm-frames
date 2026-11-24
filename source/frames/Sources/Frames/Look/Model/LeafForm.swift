//
//  LeafForm.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The form a leaf's value takes. Numbers, colours, fixed-length number lists and corner radii are timed; names,
// booleans, files and static numbers, which decide faces, shaping or line breaks, are static. Corner radii are one
// number for every corner or four, `[topLeft, topRight, bottomRight, bottomLeft]`, and resolve gives them as four
// (FRAMES-11 Shapes).
enum LeafForm: Equatable, Sendable {
    case number
    case color
    case numbers(count: Int)
    case corners
    case name
    case boolean
    case file
    case staticNumber

    // MARK: - Property
    var isTimed: Bool {
        switch self {
        case .number, .color, .numbers, .corners:
            true

        case .name, .boolean, .file, .staticNumber:
            false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
