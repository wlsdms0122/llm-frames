//
//  PresetSpan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// An animation span with the name of the preset it comes from.
struct PresetSpan: Equatable, Sendable {
    // MARK: - Property
    let preset: String
    let span: AnimationSpan

    // MARK: - Initializer
    init(preset: String, span: AnimationSpan) {
        self.preset = preset
        self.span = span
    }

    // MARK: - Public
    // MARK: - Private
}
