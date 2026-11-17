//
//  ExtensionLauncher.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Darwin
import Foundation

// Runs `frames-<name>` from `PATH` for a command frames does not have, with the global options as written before
// the arguments after the name, and standard input, output and error passed through, then waits for it to end.
struct ExtensionLauncher: Sendable {
    // MARK: - Property
    private let variables: [String: String]

    // MARK: - Initializer
    init(variables: [String: String]) {
        self.variables = variables
    }

    // MARK: - Public
    // The extension's exit code, or nil when no `frames-<name>` is on `PATH`.
    func run(
        _ name: String,
        options: [String],
        arguments: [String]
    ) throws -> Int32? {
        guard let path = executable(named: "frames-\(name)") else { return nil }

        return try spawn(path, arguments: options + arguments)
    }

    // MARK: - Private
    // A name with a `/` would reach outside `PATH`, so it names no extension.
    private func executable(named name: String) -> String? {
        guard !name.contains("/") else { return nil }

        let directories = (variables["PATH"] ?? "").split(separator: ":").map(String.init)

        return directories
            .map { URL(fileURLWithPath: $0, isDirectory: true).appendingPathComponent(name).path }
            .first { path in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                    && !isDirectory.boolValue
                    && FileManager.default.isExecutableFile(atPath: path)
            }
    }

    // The child inherits this process's standard streams, since no file actions are given.
    private func spawn(
        _ path: String,
        arguments: [String]
    ) throws -> Int32 {
        let argv = ([path] + arguments).map { strdup($0) } + [nil]
        let environment = variables.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            environment.forEach { free($0) }
        }

        var process: pid_t = 0
        let result = posix_spawn(&process, path, nil, nil, argv, environment)
        guard result == 0 else {
            throw CommandError.unstartableExtension(path: path, reason: String(cString: strerror(result)))
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
