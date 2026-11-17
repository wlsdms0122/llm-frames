//
//  PresetEntry.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// A preset as `presets` lists it: its kind, the name a document gives it (a bare name when built in, `<pack>/<name>`
// in a pack) and its description.
package struct PresetEntry: Equatable, Sendable {
    // MARK: - Property
    package let kind: PresetKind
    package let name: String
    package let description: String

    // MARK: - Initializer
    init(
        kind: PresetKind,
        name: String,
        description: String
    ) {
        self.kind = kind
        self.name = name
        self.description = description
    }

    // MARK: - Public
    // MARK: - Private
}
