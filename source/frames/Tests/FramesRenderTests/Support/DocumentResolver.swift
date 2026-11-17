//
//  DocumentResolver.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesAVFoundation
import FramesCoreText
import FramesPointTracker
import FramesTestMedia
import FramesVision

@testable import Frames

// Resolves a document on the real decoder, OCR, tracker and shaper, with no pack installed and the built in
// presets written into a directory of its own, as `render` would before it hands the document to the roles.
struct DocumentResolver {
    // MARK: - Property
    // The base theme's defaults name it, so a theme without it stops.
    private static let pop = #"""
        { "description": "pops in", "entrance": { "seconds": 0.25, "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 1, "scale": 1 } ] } }
        """#

    private let presets: TemporaryDirectory
    private let decoder = AVFoundationDecoder()

    // MARK: - Initializer
    // `presets` are preset files by `<kind>/<name>`, as `transition/push`.
    init(presets: [String: String] = [:]) throws {
        let directory = try TemporaryDirectory()
        for (name, text) in presets.merging(["animation/pop": Self.pop], uniquingKeysWith: { written, _ in written }) {
            let file = URL(fileURLWithPath: directory.file("\(name).json"))
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(text.utf8).write(to: file)
        }

        self.presets = directory
    }

    // MARK: - Public
    func resolve(_ text: String) throws -> ResolvedDocument {
        try ResolvedDocument(plan: try planner().plan(try JSONReader().read(text)), hashes: FileHasher())
    }

    // MARK: - Private
    private func planner() -> DocumentPlanner {
        let directory = URL(fileURLWithPath: presets.path, isDirectory: true)
        let packs = PackLibrary(installed: directory)
        let library = ReferenceLibrary(packs: packs, mediaFacts: decoder)

        return DocumentPlanner(
            mediaFacts: decoder,
            presets: PresetLibrary(builtIn: directory, packs: packs),
            ocr: VisionOCR(decoder: decoder),
            tracker: PointTracker(decoder: decoder),
            shaper: CoreTextShaper(),
            library: library
        )
    }
}
