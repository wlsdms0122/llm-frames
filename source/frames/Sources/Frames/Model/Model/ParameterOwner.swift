//
//  ParameterOwner.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What publishes the parameters a value is checked with. A template's stand anywhere a value of their type is taken, and
// a preset's only for a number, a colour or an ease.
enum ParameterOwner: Sendable {
    case template
    case preset

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
