//
//  BorderForm.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A media clip's border as written: `true` draws the theme `border`, and a colour draws it in that colour instead.
// `false` draws none, so it reads as no form.
enum BorderForm: Equatable, Sendable {
    case theme
    case color(String)

    // MARK: - Property
    // MARK: - Initializer
    init?(value: JSONValue) {
        if value.boolValue == true {
            self = .theme
            return
        }
        guard let color = value.stringValue else { return nil }

        self = .color(color)
    }

    // MARK: - Public
    // MARK: - Private
}
