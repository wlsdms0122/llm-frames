//
//  CommandEnvironment.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// What a command finds outside its arguments: the environment variables, where the presets and packs that ship with
// frames are, and standard input.
package struct CommandEnvironment: Sendable {
    // MARK: - Property
    // The built in presets and the shipped packs are resources of this module, in the bundle next to the tool.
    package static var current: CommandEnvironment {
        let resources = Bundle.module.resourceURL ?? Bundle.module.bundleURL

        return CommandEnvironment(
            variables: ProcessInfo.processInfo.environment,
            builtInPresets: resources.appendingPathComponent("presets", isDirectory: true),
            shippedPacks: resources.appendingPathComponent("packs", isDirectory: true),
            standardInput: { FileHandle.standardInput.readDataToEndOfFile() }
        )
    }

    let variables: [String: String]
    let builtInPresets: URL
    let shippedPacks: URL
    private let standardInput: @Sendable () -> Data

    // MARK: - Initializer
    package init(
        variables: [String: String],
        builtInPresets: URL,
        shippedPacks: URL,
        standardInput: @escaping @Sendable () -> Data
    ) {
        self.variables = variables
        self.builtInPresets = builtInPresets
        self.shippedPacks = shippedPacks
        self.standardInput = standardInput
    }

    // MARK: - Public
    func readStandardInput() -> Data {
        standardInput()
    }

    // MARK: - Private
}
