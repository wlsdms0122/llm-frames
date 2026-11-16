//
//  CommandOutput.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// Where a command writes: what it reports on standard output, and why it stopped on standard error.
package struct CommandOutput: Sendable {
    // MARK: - Property
    package static let standard = CommandOutput(
        standardOutput: { FileHandle.standardOutput.write(Data($0.utf8)) },
        standardError: { FileHandle.standardError.write(Data($0.utf8)) }
    )

    private let standardOutput: @Sendable (String) -> Void
    private let standardError: @Sendable (String) -> Void

    // MARK: - Initializer
    package init(
        standardOutput: @escaping @Sendable (String) -> Void,
        standardError: @escaping @Sendable (String) -> Void
    ) {
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    // MARK: - Public
    func write(_ text: String) {
        standardOutput(text)
    }

    func writeError(_ text: String) {
        standardError(text)
    }

    // MARK: - Private
}
