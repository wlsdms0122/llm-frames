//
//  ChoiceOrigin.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Where a transition or animation choice is written, so a preset it names that is not there stops where it can be
// fixed: on the clip, or in the theme in effect.
enum ChoiceOrigin: Equatable, Sendable {
    case clip(place: Place, kind: ClipKind)
    case theme(place: Place, kind: String)

    // MARK: - Property
    // MARK: - Initializer
    init<Choice>(_ themeDefault: ThemeDefault<Choice>) {
        self = .theme(place: themeDefault.place, kind: themeDefault.kind)
    }

    // MARK: - Public
    func unknownPreset(
        kind presetKind: String,
        name: String
    ) -> any Error {
        switch self {
        case let .clip(place, kind):
            ResolveError.unknownPreset(place: place, kind: .clip(kind), presetKind: presetKind, name: name)

        case let .theme(place, kind):
            ThemeError.unknownPreset(place: place, kind: kind, presetKind: presetKind, name: name)
        }
    }

    // MARK: - Private
}
