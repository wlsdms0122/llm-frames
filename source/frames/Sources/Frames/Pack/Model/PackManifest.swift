//
//  PackManifest.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What frames reads of a pack's manifest: the name in `[open-package]` and the range in `[frames] engine`.
struct PackManifest: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let engine: EngineRange

    // MARK: - Initializer
    init(
        name: String,
        engine: EngineRange
    ) {
        self.name = name
        self.engine = engine
    }

    // MARK: - Public
    // MARK: - Private
}
