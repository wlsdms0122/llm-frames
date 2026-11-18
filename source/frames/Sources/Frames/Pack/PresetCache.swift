//
//  PresetCache.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

import Foundation

// The presets of one kind a library has read, by name, each read and checked once, since a document names the same
// preset on many clips. A name that finds no preset is kept as nil, and one whose reading stops is read again.
final class PresetCache<Preset: Sendable>: @unchecked Sendable {
    // MARK: - Property
    private let lock = NSLock()
    private var presets: [String: PublishedPreset<Preset>?] = [:]

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func preset(
        named name: String,
        reading read: () throws -> PublishedPreset<Preset>?
    ) throws -> PublishedPreset<Preset>? {
        if let preset = lock.withLock({ presets[name] }) {
            return preset
        }

        let preset = try read()
        lock.withLock {
            presets[name] = .some(preset)
        }

        return preset
    }

    // MARK: - Private
}
