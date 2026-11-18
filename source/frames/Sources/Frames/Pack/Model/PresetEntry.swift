//
//  PresetEntry.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// A preset as `presets` and `packs` list it: its kind, the name a document gives it (`<pack>/<name>`), its description
// and the parameters it publishes.
package struct PresetEntry: Equatable, Sendable {
    // MARK: - Property
    package let kind: PresetKind
    package let name: String
    package let description: String
    package let parameters: [Parameter]

    // MARK: - Initializer
    init(
        kind: PresetKind,
        name: String,
        description: String,
        parameters: [Parameter]
    ) {
        self.kind = kind
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    // MARK: - Public
    // MARK: - Private
}
