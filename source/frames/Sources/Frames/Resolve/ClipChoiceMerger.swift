//
//  ClipChoiceMerger.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Merges a clip's preset choice over the theme's default for it with the look merge: a choice that names a preset, a
// list and an off name replace the default whole, an op merges over a default op of its own kind, and an object
// without `preset` changes it key by key. A clip that takes no default merges over nothing, so such an object there
// stops, naming the clip and the theme layer that gave the default, unless the choice stands for what it writes
// there, as an animation choice does.
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
        let over = reader.value(of: written, as: structure)
        // A choice that names a preset is the clip's whole, whatever preset the default names.
        let below = Self.namesPreset(over)
            ? nil
            : defaults.flatMap(theme.value(at:)).map { reader.value(of: $0, as: structure) }
        let layer = defaults.map { path in theme.place(of: path.reduce(Place.root) { $0.appending(key: $1) }) }

        do {
            let merged = try merger.merge(below, over, as: structure, place: place)
            return merged.json(as: structure) ?? written
        } catch LookError.nothingBelow {
            throw ResolveError.partialChoiceOverNone(place: place, kind: kind, layer: layer)
        } catch LookError.partialOverList {
            throw ResolveError.partialChoiceOverList(place: place, kind: kind, layer: layer ?? place)
        } catch let LookError.presetEntryOverKind(_, entryKind) {
            throw ResolveError.presetEntryOverKind(place: place, kind: kind, layer: layer ?? place, entryKind: entryKind)
        }
    }

    // MARK: - Private
    private static func namesPreset(_ value: LookValue) -> Bool {
        guard case let .form(name, _) = value else { return false }

        return name.hasPrefix(ValueStructure.presetKind + ":")
    }
}
