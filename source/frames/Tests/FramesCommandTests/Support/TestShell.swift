//
//  TestShell.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesTestMedia

@testable import FramesCommand

// A shell with its own `FRAMES_HOME` and shipped packs in a temporary directory, so a command runs in process without
// the bundle or what is installed on the machine, and the output of its last run is kept. The shipped `frames` pack
// holds `pop` alone. The frames executable it gives a tool is a path in the temporary directory, which nothing runs.
final class TestShell {
    // MARK: - Property
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

    var shipped: URL {
        URL(fileURLWithPath: directory.file("shipped"), isDirectory: true)
    }

    var executable: URL {
        URL(fileURLWithPath: directory.file("bin/frames"))
    }

    // The presets of the shipped `frames` pack, one folder per kind.
    var framesPresets: URL {
        shipped.appendingPathComponent("frames/presets", isDirectory: true)
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
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
        try addPack("frames", manifest: #"{ "engine": "^0.1", "name": "Frames" }"#, in: shipped)
        try write(Self.pop, to: framesPresets.appendingPathComponent("animation/pop.json"))
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
            executable: executable,
            shippedPacks: shipped,
            standardInput: { Data(input.utf8) }
        )

        recorder.clear()

        return CommandShell(environment: environment, output: recorder.output).run(arguments)
    }

    // A pack with a `pack.json` for frames 1, installed unless another directory is given.
    @discardableResult
    func addPack(
        _ name: String,
        manifest: String = #"{ "engine": "^0.1", "name": "Shorts", "version": "1.2.0", "description": "Looks for shorts" }"#,
        in packs: URL? = nil
    ) throws -> URL {
        let directory = (packs ?? installed).appendingPathComponent(name, isDirectory: true)
        try write(manifest, to: directory.appendingPathComponent("pack.json"))

        return directory
    }

    // A tool `name` of the pack in `pack`, whose `tool.json` runs `script`, made executable.
    @discardableResult
    func addTool(
        _ name: String,
        in pack: URL,
        script: String
    ) throws -> URL {
        let directory = pack.appendingPathComponent("tools/\(name)", isDirectory: true)
        try write(#"{ "description": "a tool for tests", "run": "\#(name).sh" }"#, to: directory.appendingPathComponent("tool.json"))
        let program = try write(script, to: directory.appendingPathComponent("\(name).sh"))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: program.path)

        return program
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
