//
//  TextOrientation.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// How a run's characters stand in a vertical line, as CSS `text-orientation` names it: each by its
// Vertical_Orientation, every one upright, or every one turned 90 degrees clockwise. A horizontal line turns none.
enum TextOrientation: String, CaseIterable, Equatable, Sendable {
    case mixed
    case upright
    case sideways

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Whether `character` stands upright in a vertical line. Under `mixed` it is the Vertical_Orientation of its first
    // scalar, as UAX #50 orients a grapheme cluster, and always upright when it holds an enclosing mark, which a turned
    // base would leave.
    func isUpright(_ character: Character) -> Bool {
        switch self {
        case .mixed:
            guard let first = character.unicodeScalars.first else { return false }
            let isEnclosed = character.unicodeScalars.contains { $0.properties.generalCategory == .enclosingMark }

            return isEnclosed || VerticalOrientation(first).isUpright

        case .upright:
            return true

        case .sideways:
            return false
        }
    }

    // MARK: - Private
}
