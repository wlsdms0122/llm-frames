//
//  CommandEnvironment.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// What a command finds outside its arguments: the environment variables, where the built in presets are, and standard
// input.
package struct CommandEnvironment: Sendable {
    // MARK: - Property
    // The built in presets are resources of this module, in the bundle next to the tool.
    package static var current: CommandEnvironment {
        let resources = Bundle.module.resourceURL ?? Bundle.module.bundleURL

        return CommandEnvironment(
            variables: ProcessInfo.processInfo.environment,
            builtInPresets: resources.appendingPathComponent("presets", isDirectory: true),
            standardInput: { FileHandle.standardInput.readDataToEndOfFile() }
        )
    }

    let variables: [String: String]
    let builtInPresets: URL
    private let standardInput: @Sendable () -> Data

    // MARK: - Initializer
    package init(
        variables: [String: String],
        builtInPresets: URL,
        standardInput: @escaping @Sendable () -> Data
    ) {
        self.variables = variables
        self.builtInPresets = builtInPresets
        self.standardInput = standardInput
    }

    // MARK: - Public
    func readStandardInput() -> Data {
        standardInput()
    }

    // MARK: - Private
}
