//
//  FilterResolver.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Resolves a filter choice to the operations it applies, in order, each preset read with its arguments. The names its
// operations hold are resolved to values in `theme`.
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
    // Each preset's stops name the place its choice writes it.
    func operations(
        of choice: FilterChoice,
        theme: MergedTheme,
        kind: PlaceKind
    ) throws -> [FilterOperation] {
        try choice.presets.flatMap { instance in
            guard let preset = try presets.filter(instance) else {
                throw ResolveError.unknownPreset(place: instance.place, kind: kind, presetKind: "filter", name: instance.name)
            }

            return try preset.operations.map { operation in
                try values.operation(operation, theme: theme, place: instance.place, kind: kind)
            }
        }
    }

    // The theme found the presets of its default filter, so only their values are left, each named where the theme
    // names its preset.
    func operations(
        of presets: [ThemeFilterPreset],
        theme: MergedTheme
    ) throws -> [FilterOperation] {
        try presets.flatMap { filter in
            try filter.preset.operations.map { operation in
                try values.operation(operation, theme: theme, place: filter.place, kind: .themeDefaults)
            }
        }
    }

    // MARK: - Private
}
