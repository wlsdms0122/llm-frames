//
//  TestShell.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesTestMedia

@testable import FramesCommand

// A shell with its own `FRAMES_HOME` and built in presets in a temporary directory, so a command runs in process
// without the bundle or what is installed on the machine, and the output of its last run is kept.
final class TestShell {
    // MARK: - Property
    // The base theme's defaults name it, so a theme without it stops.
    private static let pop = #"""
        { "description": "pops in", "entrance": { "seconds": 0.25, "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 1, "scale": 1 } ] } }
        """#

    let directory: TemporaryDirectory
    private let recorder = OutputRecorder()

    var home: URL {
        URL(fileURLWithPath: directory.file("home"), isDirectory: true)
    }

    var installed: URL {
        home.appendingPathComponent("packs", isDirectory: true)
    }

    var builtIn: URL {
        URL(fileURLWithPath: directory.file("presets"), isDirectory: true)
    }

    var standardOutput: String {
        recorder.standardOutput
    }

    var standardError: String {
        recorder.standardError
    }

    // MARK: - Initializer
    init() throws {
        directory = try TemporaryDirectory()
        for url in [installed, builtIn] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try write(Self.pop, to: builtIn.appendingPathComponent("animation/pop.json"))
    }

    // MARK: - Public
    // `variables` are added to the environment, which holds `FRAMES_HOME` and a `PATH` of the system tools.
    @discardableResult
    func run(
        _ arguments: [String],
        input: String = "",
        variables: [String: String] = [:]
    ) -> Int32 {
        let environment = CommandEnvironment(
            variables: ["FRAMES_HOME": home.path, "PATH": "/usr/bin:/bin"].merging(variables) { _, given in given },
            builtInPresets: builtIn,
            standardInput: { Data(input.utf8) }
        )

        recorder.clear()

        return CommandShell(environment: environment, output: recorder.output).run(arguments)
    }

    // An installed pack with a `pack.json` for frames 1.
    @discardableResult
    func addPack(
        _ name: String,
        manifest: String = #"{ "engine": "^1", "name": "Shorts", "version": "1.2.0", "description": "Looks for shorts" }"#
    ) throws -> URL {
        let directory = installed.appendingPathComponent(name, isDirectory: true)
        try write(manifest, to: directory.appendingPathComponent("pack.json"))

        return directory
    }

    @discardableResult
    func write(
        _ text: String,
        to file: URL
    ) throws -> URL {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)

        return file
    }

    // A file in the temporary directory, by its name there.
    @discardableResult
    func write(
        _ text: String,
        named name: String
    ) throws -> String {
        try write(text, to: URL(fileURLWithPath: directory.file(name))).path
    }

    // MARK: - Private
}
