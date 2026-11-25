//
//  PresetProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Finds the preset a choice names, by its name (`<pack>/<name>` or an absolute path), read with the arguments the
// choice passes. A preset that is not there is nil, and one that is there but broken, or that its arguments break,
// throws.
protocol PresetProvider: Sendable {
    func transition(_ instance: PresetInstance) throws -> TransitionPreset?
    func animation(_ instance: PresetInstance) throws -> AnimationPreset?
    func filter(_ instance: PresetInstance) throws -> FilterPreset?
    // A filter as published, with its parameters and where its ops refer to them, which a timed argument fills.
    func publishedFilter(named name: String) throws -> PublishedPreset<FilterPreset>?
    func audio(_ instance: PresetInstance) throws -> AudioPreset?
    // An audio preset as published, with its parameters and where its ops refer to them, which a timed argument fills.
    func publishedAudio(named name: String) throws -> PublishedPreset<AudioPreset>?
    // A head preset, which publishes no parameters and so is found by its name alone.
    func head(named name: String) throws -> StrokeHead?
    // The presets of `kind` the pack `pack` holds, by the names a document gives them, in name order, or nil where no
    // pack has that name.
    func names(
        of kind: PresetKind,
        inPack pack: String
    ) throws -> [String]?
}

extension PresetProvider {
    // The stop for `name`, which finds no preset of `kind`, with what the presets that are there say about it.
    func unknown(
        _ kind: PresetKind,
        named name: String
    ) throws -> UnknownPreset {
        try UnknownPreset(kind: kind, name: name) { pack in try names(of: kind, inPack: pack) }
    }
}
