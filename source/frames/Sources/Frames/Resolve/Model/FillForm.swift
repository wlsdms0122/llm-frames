//
//  FillForm.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape's `fill` as written: a colour, or `false`, which turns off its style's fill.
enum FillForm: Equatable, Sendable {
    case color(String)
    case off

    // MARK: - Property
    // MARK: - Initializer
    init?(value: JSONValue) {
        if let color = value.stringValue {
            self = .color(color)
            return
        }
        guard value.boolValue == false else { return nil }

        self = .off
    }

    // MARK: - Public
    // MARK: - Private
}
