//
//  PackDirectory.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Foundation

@testable import Frames

// A temporary directory with room for installed packs, shipped packs and built in presets, removed when the test
// that made it ends.
final class PackDirectory {
    // MARK: - Property
    let root: URL

    var installed: URL {
        root.appendingPathComponent("installed", isDirectory: true)
    }

    var shipped: URL {
        root.appendingPathComponent("shipped", isDirectory: true)
    }

    var builtIn: URL {
        root.appendingPathComponent("presets", isDirectory: true)
    }

    var packs: PackLibrary {
        PackLibrary(installed: installed, shipped: shipped)
    }

    // MARK: - Initializer
    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("frames-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shipped, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Public
    // A pack with a manifest for frames 1, in `packs`, the installed packs unless another directory is given.
    @discardableResult
    func addPack(
        _ name: String,
        engine: String = "^1.0",
        in packs: URL? = nil
    ) throws -> URL {
        let directory = (packs ?? installed).appendingPathComponent(name, isDirectory: true)
        try write(
            """
            [open-package]
            version = "1.0.0"

            [package]
            name = "A pack for tests"
            version = "1.0.0"

            [frames]
            engine = "\(engine)"
            """,
            to: directory.appendingPathComponent("manifest.toml")
        )

        return directory
    }

    // Writes a file in an installed pack, `path` from the pack's directory.
    @discardableResult
    func write(
        _ text: String,
        in pack: String,
        at path: String
    ) throws -> URL {
        let file = installed.appendingPathComponent(pack, isDirectory: true).appendingPathComponent(path)
        try write(text, to: file)

        return file
    }

    func write(
        _ text: String,
        to file: URL
    ) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)
    }

    func library(mediaFacts: any MediaFactProvider = Fixture.mediaFacts) -> ReferenceLibrary {
        ReferenceLibrary(packs: packs, mediaFacts: mediaFacts)
    }

    // MARK: - Private
}
