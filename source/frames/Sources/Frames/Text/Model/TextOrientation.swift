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
    // MARK: - Private
}
