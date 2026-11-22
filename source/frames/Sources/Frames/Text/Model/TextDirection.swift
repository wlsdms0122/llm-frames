//
//  TextDirection.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// A direction text is laid out in, as CSS `direction` names it: a paragraph direction of UAX #9, or the direction of
// an embedding level, left to right at an even level and right to left at an odd one.
package enum TextDirection: String, CaseIterable, Equatable, Sendable {
    case ltr
    case rtl

    // MARK: - Property
    var paragraphLevel: Int {
        switch self {
        case .ltr:
            0

        case .rtl:
            1
        }
    }

    // The side a paragraph in this direction starts from, as CSS `text-align: start` takes it.
    var start: TextAlignment {
        switch self {
        case .ltr:
            .left

        case .rtl:
            .right
        }
    }

    // MARK: - Initializer
    init(level: Int) {
        self = level % 2 == 0 ? .ltr : .rtl
    }

    // MARK: - Public
    // MARK: - Private
}
