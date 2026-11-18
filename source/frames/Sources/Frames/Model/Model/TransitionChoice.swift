//
//  TransitionChoice.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A transition choice as a document, a theme or a template writes it. `seconds` replaces the preset's own when the
// choice gives it.
enum TransitionChoice: Equatable, Sendable {
    case cut
    case preset(PresetInstance, seconds: Double?)

    // MARK: - Property
    // MARK: - Initializer
    // `place` is where the choice is written.
    init?(
        value: JSONValue,
        place: Place
    ) {
        guard value != .string("cut") else {
            self = .cut
            return
        }
        guard let instance = PresetInstance(value: value, place: place) else { return nil }

        self = .preset(instance, seconds: value.objectValue?["seconds"]?.numberValue)
    }

    // MARK: - Public
    // MARK: - Private
}
