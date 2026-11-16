//
//  MotionProperty.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum MotionProperty: String, CaseIterable, Sendable {
    case opacity
    case scale
    case x
    case y
    case rotation
    case reveal
    case nudge

    // MARK: - Property
    var defaultValue: Double {
        switch self {
        case .opacity, .scale, .reveal:
            1

        case .x, .y, .rotation, .nudge:
            0
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
