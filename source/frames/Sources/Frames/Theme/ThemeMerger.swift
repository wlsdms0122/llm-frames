//
//  ThemeMerger.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Merges theme layers from weakest to strongest by the look merge: the base theme, a --theme file, a document's
// theme. The merged theme's values are checked against their structure, so resolve reads only values it takes. A stop
// names the layer that writes the value it names, or the base theme where none does.
struct ThemeMerger: Sendable {
    // MARK: - Property
    private let validator = ThemeValidator()
    private let reader = LookReader()
    private let merger = LookMerger()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func merge(
        _ layers: [ThemeLayer],
        over base: MergedTheme = .base
    ) throws -> MergedTheme {
        for layer in layers {
            try validator.checkKeys(of: layer)
        }

        let structure = LookStructureTable.theme
        let all = base.layers + layers
        var value = reader.value(of: base.value, as: structure)
        do {
            for layer in layers {
                value = try merger.merge(value, reader.value(of: layer.value, as: structure), as: structure, place: .root)
            }
            try merger.checkRequired(in: value, as: structure, place: .root)
            try structure.checkDomains(of: value.json(as: structure) ?? .null, place: .root)
        } catch let error as LookError {
            let written = MergedTheme(value: value.json(as: structure) ?? .null, layers: all)
            throw error.placed { written.place(of: $0) }
        }

        let merged = MergedTheme(value: value.json(as: structure) ?? .object(JSONObject()), layers: all)
        try validator.checkReferences(in: merged)

        return merged
    }

    // MARK: - Private
}
