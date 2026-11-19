//
//  MixFilterEntry.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// An entry of a segment's audio filter: its ops in order, run on the entry's input, and the `mix` from 0 to 1 its
// output takes of their result against that input.
package struct MixFilterEntry: Equatable, Sendable {
    // MARK: - Property
    package let operations: [MixFilterOperation]
    package let mix: MixValue

    // MARK: - Initializer
    package init(
        operations: [MixFilterOperation],
        mix: MixValue
    ) {
        self.operations = operations
        self.mix = mix
    }

    // MARK: - Public
    // MARK: - Private
}
