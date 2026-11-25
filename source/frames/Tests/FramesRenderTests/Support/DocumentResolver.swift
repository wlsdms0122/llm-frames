//
//  DocumentResolver.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesAVFoundation
import FramesCoreText
import FramesTestMedia

@testable import Frames

// Resolves a document on the real decoder and shaper, with the shipped `frames` pack holding `pop` alone
// and the presets a test gives in an installed pack `mine`, as `render` would before it hands the document to the
// roles.
struct DocumentResolver {
    // MARK: - Property
    private static let pop = #"""
        { "description": "pops in", "entrance": { "seconds": 0.25, "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 1, "scale": 1 } ] } }
        """#
    private static let manifest = #"{ "engine": "^0.1" }"#

    private let directory: TemporaryDirectory
    private let decoder = AVFoundationDecoder()

    // MARK: - Initializer
    // `presets` are preset files by `<kind>/<name>`, as `transition/push`, named `mine/<name>` in a document.
    init(presets: [String: String] = [:]) throws {
        let directory = try TemporaryDirectory()
        var files = ["shipped/frames/pack.json": Self.manifest, "shipped/frames/presets/animation/pop.json": Self.pop]
        files["installed/mine/pack.json"] = Self.manifest
        for (name, text) in presets {
            files["installed/mine/presets/\(name).json"] = text
        }
        for (name, text) in files {
            let file = URL(fileURLWithPath: directory.file(name))
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(text.utf8).write(to: file)
        }

        self.directory = directory
    }

    // MARK: - Public
    func resolve(_ text: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: try planner().plan(try JSONReader().read(text)), hashes: FileHasher())
    }

    // MARK: - Private
    private func planner() -> DocumentPlanner {
        let packs = PackLibrary(
            installed: URL(fileURLWithPath: directory.file("installed"), isDirectory: true),
            shipped: URL(fileURLWithPath: directory.file("shipped"), isDirectory: true)
        )
        let library = ReferenceLibrary(packs: packs, mediaFacts: decoder)

        return DocumentPlanner(
            mediaFacts: decoder,
            presets: PresetLibrary(packs: packs),
            shaper: CoreTextShaper(),
            library: library
        )
    }
}
