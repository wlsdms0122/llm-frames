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
    // Whether `character` stands upright in a vertical line, under `mixed` by its Vertical_Orientation.
    func isUpright(_ character: Character) -> Bool {
        switch self {
        case .mixed:
            return VerticalOrientation(character).isUpright

        case .upright:
            return true

        case .sideways:
            return false
        }
    }

    // Whether `character` is set in its face's vertical forms in a vertical line: an upright character but, under
    // `upright`, one whose Vertical_Orientation is R, which stands in its face's horizontal form.
    func isInVerticalForms(_ character: Character) -> Bool {
        isUpright(character) && VerticalOrientation(character).isUpright
    }

    // MARK: - Private
}
