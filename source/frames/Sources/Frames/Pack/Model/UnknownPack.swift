//
//  UnknownPack.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A pack name that finds no pack, with the packs there are and the one near it, as a name whose pack is not there
// gives them (FRAMES-17 Packs).
package struct UnknownPack: Equatable, Sendable, CustomStringConvertible {
    // MARK: - Property
    let name: String
    // The names of the packs there are, in name order.
    let packs: [String]
    // The one of `packs` near `name`, where one is.
    let nearest: String?

    package var description: String {
        let there = packs.isEmpty ? "There are no packs" : "The packs are \(packs.joined(separator: ", "))"

        return "unknown pack \(quoted(name)). " + (nearest.map { "Did you mean the pack \(quoted($0))? " } ?? "") + there
    }

    // MARK: - Initializer
    init(
        name: String,
        packs: [String]
    ) {
        self.name = name
        self.packs = packs
        self.nearest = NameHint.nearest(to: name, among: packs)
    }

    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }
}
