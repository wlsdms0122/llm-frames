//
//  UnknownReference.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A name of one kind that finds nothing, with what its message adds about the name (FRAMES-17 Packs). Every stop for
// such a name, of any kind and wherever it is written, says it in these words.
package struct UnknownReference: Equatable, Sendable, CustomStringConvertible {
    // MARK: - Property
    let kind: ReferenceKind
    let name: String
    // Nil where the name is an absolute path of a kind that takes one, which names a file and no name a pack holds.
    let hint: NameHint?

    package var description: String {
        let quotedName = JSONValue.string(name).written
        guard let hint else { return "\(kind.word) \(quotedName) is not there" }

        return "unknown \(kind.word) \(quotedName)" + hint.text(things: kind.plural, rule: kind.rule)
    }

    // MARK: - Initializer
    init(
        kind: ReferenceKind,
        name: String,
        hint: NameHint?
    ) {
        self.kind = kind
        self.name = name
        self.hint = hint
    }

    // `packs` gives the names of the packs there are, and `names` the names of the kind a pack holds, as
    // `<pack>/<name>`, or nil where no pack has that name.
    package init(
        kind: ReferenceKind,
        name: String,
        packs: () throws -> [String],
        names: (String) throws -> [String]?
    ) rethrows {
        if case .path = PackReference(name), kind.takesPath {
            self.init(kind: kind, name: name, hint: nil)
        } else {
            self.init(kind: kind, name: name, hint: try NameHint(name: name, packs: packs, names: names))
        }
    }

    // MARK: - Public
    // MARK: - Private
}
