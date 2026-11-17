//
//  PresetLibrary.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Finds a preset by the name a document or theme gives it: `<pack>/<name>` in that pack's presets, or an absolute
// path.
package struct PresetLibrary: PresetProvider {
    // MARK: - Property
    private let packs: PackLibrary
    private let reader = PresetReader()

    // MARK: - Initializer
    package init(packs: PackLibrary) {
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
    // Every preset of a kind, each pack's in pack order, each read and checked, so a preset that would stop a document
    // stops the listing too.
    package func presets(of kind: PresetKind) throws -> [PresetEntry] {
        try packs.packs().flatMap { pack in
            try presets(of: kind, in: pack)
        }
    }

    package func presets(
        of kind: PresetKind,
        in pack: Pack
    ) throws -> [PresetEntry] {
        try names(of: kind, in: pack).compactMap { try entry(named: $0, kind: kind) }
    }

    // A preset's file as it is written, found by the name a document gives it.
    package func text(
        named name: String,
        kind: PresetKind
    ) throws -> String? {
        guard let file = try file(named: name, kind: kind.rawValue), let data = try packs.contents(of: file) else {
            return nil
        }

        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Private
    private func names(
        of kind: PresetKind,
        in pack: Pack
    ) throws -> [String] {
        try packs.names(in: "presets/\(kind.rawValue)", of: pack, pathExtension: "json").map { "\(pack.name)/\($0)" }
    }

    private func entry(
        named name: String,
        kind: PresetKind
    ) throws -> PresetEntry? {
        let description = switch kind {
        case .transition:
            try transition(named: name)?.description

        case .animation:
            try animation(named: name)?.description

        case .filter:
            try filter(named: name)?.description
        }

        return description.map { PresetEntry(kind: kind, name: name, description: $0) }
    }

    private func value(
        named name: String,
        kind: String
    ) throws -> JSONValue? {
        guard let file = try file(named: name, kind: kind), let data = try packs.contents(of: file) else { return nil }

        return try JSONReader(file: name).read(data)
    }

    private func file(
        named name: String,
        kind: String
    ) throws -> URL? {
        guard let reference = PackReference(name) else { return nil }

        return try packs.file(of: reference, in: "presets/\(kind)", pathExtension: "json")
    }
}
