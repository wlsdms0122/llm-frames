//
//  ShippedHeads.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import Frames

// The head presets the pack `frames` ships, read from their files in the package's resources, so a test draws what
// `frames/<name>` names.
package enum ShippedHeads {
    // MARK: - Property
    package static let names = ["arrow", "line-arrow", "circle", "square", "diamond", "bar"]

    // MARK: - Initializer
    // MARK: - Public
    // The file of a shipped head preset, as a pack holds it.
    package static func text(_ name: String) -> String {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../Sources/FramesCommand/Resources/packs/frames/presets/head")
            .standardizedFileURL
        let file = directory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: file) else { fatalError("no shipped head \(name)") }

        return String(decoding: data, as: UTF8.self)
    }

    package static func head(_ name: String) -> StrokeHead {
        guard
            let value = try? JSONReader(file: name).read(Data(text(name).utf8)),
            let head = StrokeHead(written: value)
        else { fatalError("unreadable shipped head \(name)") }

        return head
    }

    // MARK: - Private
}
