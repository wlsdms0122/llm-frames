//
//  CommandEnvironment.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// What a command finds outside its arguments: the environment variables, the frames executable that runs the command
// line, which a tool is given, where the packs that ship with frames are, and standard input.
package struct CommandEnvironment: Sendable {
    // MARK: - Property
    // The packs that ship with frames are resources of this module, in the bundle next to the tool. The frames
    // executable is the one the main bundle names, a symbolic link it was started by as written, and the path the
    // process was started by where the bundle names none.
    package static var current: CommandEnvironment {
        let resources = Bundle.module.resourceURL ?? Bundle.module.bundleURL

        return CommandEnvironment(
            variables: ProcessInfo.processInfo.environment,
            executable: Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]),
            shippedPacks: resources.appendingPathComponent("packs", isDirectory: true),
            standardInput: { FileHandle.standardInput.readDataToEndOfFile() }
        )
    }

    let variables: [String: String]
    let executable: URL
    let shippedPacks: URL
    private let standardInput: @Sendable () -> Data

    // MARK: - Initializer
    package init(
        variables: [String: String],
        executable: URL,
        shippedPacks: URL,
        standardInput: @escaping @Sendable () -> Data
    ) {
        self.variables = variables
        self.executable = executable
        self.shippedPacks = shippedPacks
        self.standardInput = standardInput
    }

    // MARK: - Public
    func readStandardInput() -> Data {
        standardInput()
    }

    // MARK: - Private
}
