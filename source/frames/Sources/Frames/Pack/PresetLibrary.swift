//
//  PresetLibrary.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Finds a preset by the name a document or theme gives it: `<pack>/<name>` in that pack's presets, or an absolute
// path. Each preset is read and checked once for the library's life, and each choice fills in its arguments.
package struct PresetLibrary: PresetProvider {
    // MARK: - Property
    private let packs: PackLibrary
    private let reader = PresetReader()
    private let transitions = PresetCache<TransitionPreset>()
    private let animations = PresetCache<AnimationPreset>()
    private let filters = PresetCache<FilterPreset>()
    private let audios = PresetCache<AudioPreset>()
    private let heads = PresetCache<HeadPreset>()

    // MARK: - Initializer
    package init(packs: PackLibrary) {
        self.packs = packs
    }

    // MARK: - Lifecycle
    func transition(_ instance: PresetInstance) throws -> TransitionPreset? {
        try publishedTransition(named: instance.name).map { try reader.transition($0, instance: instance) }
    }

    func animation(_ instance: PresetInstance) throws -> AnimationPreset? {
        try publishedAnimation(named: instance.name).map { try reader.animation($0, instance: instance) }
    }

    func filter(_ instance: PresetInstance) throws -> FilterPreset? {
        try publishedFilter(named: instance.name).map { try reader.filter($0, instance: instance) }
    }

    func publishedFilter(named name: String) throws -> PublishedPreset<FilterPreset>? {
        try filters.preset(named: name) {
            try value(named: name, kind: "filter").map { value in
                try reader.publishedFilter(from: value, place: Place(file: name, components: []))
            }
        }
    }

    func audio(_ instance: PresetInstance) throws -> AudioPreset? {
        try publishedAudio(named: instance.name).map { try reader.audio($0, instance: instance) }
    }

    func publishedAudio(named name: String) throws -> PublishedPreset<AudioPreset>? {
        try audios.preset(named: name) {
            try value(named: name, kind: PresetKind.audio.rawValue).map { value in
                try reader.publishedAudio(from: value, place: Place(file: name, components: []))
            }
        }
    }

    func head(named name: String) throws -> StrokeHead? {
        try publishedHead(named: name)?.defaults.head
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
        switch kind {
        case .transition:
            try publishedTransition(named: name).map { preset in
                PresetEntry(kind: kind, name: name, description: preset.defaults.description, parameters: preset.parameters)
            }

        case .animation:
            try publishedAnimation(named: name).map { preset in
                PresetEntry(kind: kind, name: name, description: preset.defaults.description, parameters: preset.parameters)
            }

        case .filter:
            try publishedFilter(named: name).map { preset in
                PresetEntry(kind: kind, name: name, description: preset.defaults.description, parameters: preset.parameters)
            }

        case .audio:
            try publishedAudio(named: name).map { preset in
                PresetEntry(kind: kind, name: name, description: preset.defaults.description, parameters: preset.parameters)
            }

        case .head:
            try publishedHead(named: name).map { preset in
                PresetEntry(kind: kind, name: name, description: preset.defaults.description, parameters: preset.parameters)
            }
        }
    }

    private func publishedHead(named name: String) throws -> PublishedPreset<HeadPreset>? {
        try heads.preset(named: name) {
            try value(named: name, kind: PresetKind.head.rawValue).map { value in
                try reader.publishedHead(from: value, place: Place(file: name, components: []))
            }
        }
    }

    private func publishedTransition(named name: String) throws -> PublishedPreset<TransitionPreset>? {
        try transitions.preset(named: name) {
            try value(named: name, kind: "transition").map { value in
                try reader.publishedTransition(from: value, place: Place(file: name, components: []))
            }
        }
    }

    private func publishedAnimation(named name: String) throws -> PublishedPreset<AnimationPreset>? {
        try animations.preset(named: name) {
            try value(named: name, kind: "animation").map { value in
                try reader.publishedAnimation(from: value, place: Place(file: name, components: []))
            }
        }
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
