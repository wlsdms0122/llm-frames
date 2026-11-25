//
//  UnknownTool.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A tool name that finds no tool, with what its message adds about the name (FRAMES-17 Packs).
package struct UnknownTool: Equatable, Sendable, CustomStringConvertible {
    // MARK: - Property
    let name: String
    let hint: NameHint

    package var description: String {
        "unknown tool \(JSONValue.string(name).written)"
            + hint.text(things: "tools", rule: "A tool is named <pack>/<name>, and the ones frames ships are frames/<name>")
    }

    // MARK: - Initializer
    // `names` gives the tools a pack holds, as `<pack>/<name>`, or nil where no pack has that name.
    init(
        name: String,
        names: (String) throws -> [String]?
    ) rethrows {
        self.name = name
        self.hint = try NameHint(name: name, names: names)
    }

    // MARK: - Public
    // MARK: - Private
}
