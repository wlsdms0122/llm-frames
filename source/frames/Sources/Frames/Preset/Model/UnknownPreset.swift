//
//  UnknownPreset.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A preset name that finds no preset of its kind, with what its message adds about the name (FRAMES-17 Packs). Every
// stop for such a name, in a document, a theme or `presets`, says it in these words.
package struct UnknownPreset: Equatable, Sendable, CustomStringConvertible {
    // MARK: - Property
    let kind: PresetKind
    let name: String
    let hint: NameHint

    package var description: String {
        "unknown \(kind.rawValue) preset \(JSONValue.string(name).written)"
            + hint.text(
                things: "\(kind.rawValue) presets",
                rule: "A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"
            )
    }

    // MARK: - Initializer
    init(
        kind: PresetKind,
        name: String,
        hint: NameHint
    ) {
        self.kind = kind
        self.name = name
        self.hint = hint
    }

    // `names` gives the presets of the kind a pack holds, as `<pack>/<name>`, or nil where no pack has that name.
    package init(
        kind: PresetKind,
        name: String,
        names: (String) throws -> [String]?
    ) rethrows {
        self.init(kind: kind, name: name, hint: try NameHint(name: name, names: names))
    }

    // MARK: - Public
    // MARK: - Private
}
