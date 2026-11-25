//
//  ToolLauncher.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Darwin
import Foundation
import Frames

// Runs a pack's tool with the global options as written before the arguments after its name, standard input, output
// and error passed through, and `FRAMES_EXECUTABLE` set to the frames executable that runs it, which the tool runs for
// every frames command it needs. It waits for the tool to end.
struct ToolLauncher: Sendable {
    // MARK: - Property
    static let executableVariable = "FRAMES_EXECUTABLE"

    private let variables: [String: String]
    private let framesExecutable: URL

    // MARK: - Initializer
    init(
        variables: [String: String],
        framesExecutable: URL
    ) {
        self.variables = variables
        self.framesExecutable = framesExecutable
    }

    // MARK: - Public
    // The tool's exit code.
    func run(
        _ tool: PackTool,
        options: [String],
        arguments: [String]
    ) throws -> Int32 {
        try spawn(tool.executable.path, arguments: options + arguments)
    }

    // MARK: - Private
    // The child inherits this process's standard streams, since no file actions are given.
    private func spawn(
        _ path: String,
        arguments: [String]
    ) throws -> Int32 {
        let environment = variables.merging([Self.executableVariable: framesExecutable.path]) { _, given in given }
        let argumentStrings = ([path] + arguments).map { strdup($0) } + [nil]
        let environmentStrings = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argumentStrings.forEach { free($0) }
            environmentStrings.forEach { free($0) }
        }

        var process: pid_t = 0
        let result = posix_spawn(&process, path, nil, nil, argumentStrings, environmentStrings)
        guard result == 0 else {
            throw CommandError.unstartableTool(path: path, reason: String(cString: strerror(result)))
        }

        var status: Int32 = 0
        while waitpid(process, &status, 0) == -1, errno == EINTR { }

        return exitCode(of: status)
    }

    // A child ended by a signal exits as a shell reports it, 128 plus the signal.
    private func exitCode(of status: Int32) -> Int32 {
        let signal = status & 0x7f
        guard signal == 0 else { return 128 + signal }

        return (status >> 8) & 0xff
    }
}
