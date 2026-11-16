//
//  PresetLibrary.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Finds a preset by the name a document or theme gives it: a bare name among the built in presets, `<pack>/<name>`
// in that pack's presets, or an absolute path. `builtIn` is laid out as a pack's `presets/`, one folder per kind.
struct PresetLibrary: PresetProvider {
    // MARK: - Property
    private let builtIn: URL
    private let packs: PackLibrary
    private let reader = PresetReader()

    // MARK: - Initializer
    init(
        builtIn: URL,
        packs: PackLibrary
    ) {
        self.builtIn = builtIn
        self.packs = packs
    }

    // MARK: - Lifecycle
    func transition(named name: String) throws -> TransitionPreset? {
        try value(named: name, kind: "transition").map { value in
            try reader.transition(from: value, place: Place(file: name, components: []))
        }
    }

    func animation(named name: String) throws -> AnimationPreset? {
        try value(named: name, kind: "animation").map { value in
            try reader.animation(from: value, place: Place(file: name, components: []))
        }
    }

    func filter(named name: String) throws -> FilterPreset? {
        try value(named: name, kind: "filter").map { value in
            try reader.filter(from: value, place: Place(file: name, components: []))
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func value(
        named name: String,
        kind: String
    ) throws -> JSONValue? {
        guard let reference = PackReference(name) else { return nil }

        let file: URL? = switch reference {
        case let .builtIn(preset):
            builtIn
                .appendingPathComponent(kind, isDirectory: true)
                .appendingPathComponent(preset)
                .appendingPathExtension("json")

        case .pack, .path:
            try packs.file(of: reference, in: "presets/\(kind)", pathExtension: "json")
        }
        guard let file, let data = try packs.contents(of: file) else { return nil }

        return try JSONReader(file: name).read(data)
    }
}
