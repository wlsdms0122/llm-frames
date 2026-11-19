//
//  ClipLookPlanner.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Plans one key of a clip's look as a timed value: the clip's own layer, its static value with the structure its
// keyframes give, merges over its style's value; a key the merged value requires must be given by a layer or by the
// keyframes, which give a value at every instant; the merged value, when it is on, is completed over its defaults;
// then each leaf is timed over it. Colour names become colours, a name the theme does not hold stopping where the clip
// writes it, and theme lengths become output pixels at `scale`. Keyframes move from the clip's clock to sequence time.
struct ClipLookPlanner: Sendable {
    // MARK: - Property
    private let reader = LookReader()
    private let merger = LookMerger()
    private let builder = TimedValueBuilder()

    let place: Place
    let kind: PlaceKind
    private let clock: TimeMap
    private let instant: Double
    // Output pixels per theme length.
    let scale: Double
    private let theme: MergedTheme

    // MARK: - Initializer
    init(
        place: Place,
        kind: PlaceKind,
        clock: TimeMap,
        instant: Double,
        scale: Double,
        theme: MergedTheme
    ) {
        self.place = place
        self.kind = kind
        self.clock = clock
        self.instant = instant
        self.scale = scale
        self.theme = theme
    }

    // MARK: - Public
    // `style` is the path of the theme value the clip's merges over, and `defaults` what completes the merged value.
    func timed(
        _ property: LookProperty?,
        key: String,
        as structure: ValueStructure,
        style: [String]? = nil,
        defaults: JSONValue? = nil
    ) throws -> TimedValue {
        let place = self.place.appending(key: key)
        guard let merged = try self.merged(property, key: key, as: structure, style: style), merged != .off else {
            return .off
        }

        let (written, keyframes) = read(property, as: structure)
        let lookPlace = LookPlace(clip: self.place, key: key)
        let completed = try defaults.map { defaults in
            try merger.merge(reader.value(of: defaults, as: structure), merged, as: structure, place: place)
        } ?? merged

        return try builder.timed(
            completed,
            written: written,
            keyframes: keyframes,
            as: structure,
            instant: instant,
            place: lookPlace,
            leaf: leaf(_:kind:place:)
        )
    }

    // The clip's own layer merged over the theme value at `style`, nil where no layer writes the key. A key the merged
    // value requires must be given by a layer or by the keyframes, which give a value at every instant. Only the keys
    // the structure declares are read from the theme value, since a text style holds the character and the paragraph
    // attributes in one object.
    func merged(
        _ property: LookProperty?,
        key: String,
        as structure: ValueStructure,
        style: [String]? = nil
    ) throws -> LookValue? {
        let place = self.place.appending(key: key)
        let below = style.flatMap(theme.value(at:)).map { reader.value(of: declared($0, as: structure), as: structure) }
        let (written, keyframes) = read(property, as: structure)

        let lookPlace = LookPlace(clip: self.place, key: key)
        let own = try builder.ownLayer(written: written, keyframes: keyframes, as: structure, place: lookPlace)
        let merged = try merger.merge([below, own], as: structure, place: place)
        guard let merged, merged != .off else { return merged }

        do {
            let given = try merger.merge([merged] + keyframes.map(\.value), as: structure, place: place) ?? merged
            try merger.checkRequired(in: given, as: structure, place: place)
        } catch let LookError.missingLeaf(_, missing) {
            let layer = below == .off ? style.map { path in
                theme.place(of: path.reduce(Place.root) { $0.appending(key: $1) })
            } : nil
            throw ResolveError.missingLookLeaf(place: place, kind: kind, key: missing, layer: layer)
        }

        return merged
    }

    // A key timed over a merged value its caller gives, as a choice merged over the theme's default is: the clip's
    // static value is its own layer, and its keyframes write the leaves of the merged value, completed over
    // `defaults`, so a `null` in them may point at a default.
    func timed(
        _ property: LookProperty?,
        key: String,
        over merged: LookValue,
        as structure: ValueStructure,
        defaults: JSONValue? = nil
    ) throws -> TimedValue {
        let lookPlace = LookPlace(clip: place, key: key)
        let (written, keyframes) = read(property, as: structure)
        let completed = try defaults.map { defaults in
            try merger.merge(
                reader.value(of: defaults, as: structure),
                merged,
                as: structure,
                place: place.appending(key: key)
            )
        } ?? merged
        _ = try builder.ownLayer(written: completed, keyframes: keyframes, as: structure, place: lookPlace)
        guard merged != .off else { return .off }

        return try builder.timed(
            completed,
            written: written,
            keyframes: keyframes,
            as: structure,
            instant: instant,
            place: lookPlace,
            leaf: leaf(_:kind:place:)
        )
    }

    // A leaf no keyframe moves, as `timed` gives one: a timed leaf one keyframe at the clip's instant.
    func timed(
        _ value: JSONValue,
        kind: LeafKind,
        place: Place
    ) throws -> TimedValue {
        guard kind.isTimed else { return .fixed(value) }

        return .track([Keyframe(at: instant, value: try leaf(value, kind: kind, place: place))])
    }

    // MARK: - Private
    // The clip's static value and its keyframes' values, in sequence time.
    private func read(
        _ property: LookProperty?,
        as structure: ValueStructure
    ) -> (written: LookValue?, keyframes: [PropertyKeyframe<LookValue>]) {
        let written = property?.written.map { reader.value(of: $0, as: structure) }
        let keyframes = (property?.keyframes ?? []).map { keyframe in
            PropertyKeyframe(
                index: keyframe.index,
                at: clock.sequenceTime(ofClipTime: keyframe.at),
                value: reader.value(of: keyframe.value, as: structure),
                ease: keyframe.ease
            )
        }

        return (written, keyframes)
    }

    private func declared(
        _ value: JSONValue,
        as structure: ValueStructure
    ) -> JSONValue {
        guard case let .object(object) = structure, let members = value.objectValue?.members else { return value }

        return .object(JSONObject(members: members.filter { object.structure(of: $0.key) != nil }))
    }

    private func leaf(
        _ value: JSONValue,
        kind leaf: LeafKind,
        place: Place
    ) throws -> LeafValue {
        let length = leaf.isLength ? scale : 1
        switch leaf.form {
        case .color:
            let name = value.stringValue ?? ""
            guard theme.isColor(name) else {
                throw ThemeError.unknownColor(place: place, kind: kind.label, name: name)
            }

            return .color(theme.color(name))

        case .numbers:
            return .numbers((value.arrayValue ?? []).compactMap(\.numberValue).map { $0 * length })

        case .number, .name, .boolean, .file, .staticNumber:
            return .number((value.numberValue ?? 0) * length)
        }
    }
}
