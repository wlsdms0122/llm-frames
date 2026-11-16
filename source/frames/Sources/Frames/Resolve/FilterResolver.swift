//
//  FilterResolver.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Resolves a filter choice to the operations it applies, in order: a preset name, a list of them, or `none`. The
// names its operations hold are resolved to values in `theme`.
struct FilterResolver: Sendable {
    // MARK: - Property
    private let presets: any PresetProvider
    private let values: PresetValueResolver

    // MARK: - Initializer
    init(
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.presets = presets
        self.values = PresetValueResolver(library: library)
    }

    // MARK: - Public
    func operations(
        of choice: JSONValue,
        theme: MergedTheme,
        place: Place,
        kind: PlaceKind
    ) throws -> [FilterOperation] {
        if let names = choice.arrayValue {
            return try names.enumerated().flatMap { index, name in
                try operations(of: name, theme: theme, place: place.appending(index: index), kind: kind)
            }
        }

        let name = choice.stringValue ?? "none"
        guard name != "none" else { return [] }
        guard let preset = try presets.filter(named: name) else {
            throw ResolveError.unknownPreset(place: place, kind: kind, presetKind: "filter", name: name)
        }

        return try preset.operations.map { operation in try values.operation(operation, theme: theme, place: place, kind: kind) }
    }

    // MARK: - Private
}
