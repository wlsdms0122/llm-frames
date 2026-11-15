//
//  PackManifest.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What frames reads of a pack's manifest: what the pack calls itself and its version and description in `[package]`,
// and the range in `[frames] engine`. The name is not which pack it is: that is the directory it is in.
struct PackManifest: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let version: String
    let description: String?
    let engine: EngineRange

    // MARK: - Initializer
    init(
        name: String,
        version: String,
        description: String?,
        engine: EngineRange
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.engine = engine
    }

    // MARK: - Public
    // MARK: - Private
}
