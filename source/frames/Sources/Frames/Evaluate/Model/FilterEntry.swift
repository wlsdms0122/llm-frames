//
//  FilterEntry.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// One entry of a filter as a display list draws it: its ops in order, their result mixed with the entry's input by
// `mix`, from 0 for the input as it is to 1 for the ops' result alone.
package struct FilterEntry: Equatable, Sendable {
    // MARK: - Property
    package let operations: [ResolvedFilterOperation]
    package let mix: Double

    // MARK: - Initializer
    package init(
        operations: [ResolvedFilterOperation],
        mix: Double = 1
    ) {
        self.operations = operations
        self.mix = mix
    }

    // MARK: - Public
    // MARK: - Private
}
