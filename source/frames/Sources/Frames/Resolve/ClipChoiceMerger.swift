//
//  ClipChoiceMerger.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Merges a clip's preset choice over the theme's default for it with the look merge: a choice that names a preset, a
// list and an off name replace the default whole, and an object without `preset` changes it key by key. A clip that
// takes no default merges over nothing, so such an object there stops, naming the clip and the theme layer that gave
// the default.
struct ClipChoiceMerger: Sendable {
    // MARK: - Property
    private let reader = LookReader()
    private let merger = LookMerger()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `defaults` is the path of the theme's default the clip takes, nil where it takes none.
    func merged(
        _ written: JSONValue,
        over defaults: [String]?,
        as structure: ValueStructure,
        place: Place,
        kind: PlaceKind,
        theme: MergedTheme
    ) throws -> JSONValue {
        let below = defaults.flatMap(theme.value(at:)).map { reader.value(of: $0, as: structure) }
        let layer = defaults.map { path in theme.place(of: path.reduce(Place.root) { $0.appending(key: $1) }) }

        do {
            let merged = try merger.merge(below, reader.value(of: written, as: structure), as: structure, place: place)
            return merged.json(as: structure) ?? written
        } catch LookError.nothingBelow {
            throw ResolveError.partialChoiceOverNone(place: place, kind: kind, layer: layer)
        } catch LookError.partialOverList {
            throw ResolveError.partialChoiceOverList(place: place, kind: kind, layer: layer ?? place)
        }
    }

    // MARK: - Private
}
