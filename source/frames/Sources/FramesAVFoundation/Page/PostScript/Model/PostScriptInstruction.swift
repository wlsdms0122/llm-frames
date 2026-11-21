//
//  PostScriptInstruction.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// One step of a PostScript calculator function's program (ISO 32000-1 7.10.5): an operand pushed, an operator run, or
// an `if` or `ifelse` with the procedures it chooses between, `otherwise` nil for an `if`.
indirect enum PostScriptInstruction: Equatable, Sendable {
    case operand(PostScriptValue)
    case operation(String)
    case conditional(then: [PostScriptInstruction], otherwise: [PostScriptInstruction]?)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
