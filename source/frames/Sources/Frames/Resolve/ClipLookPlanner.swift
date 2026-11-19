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

    private let place: Place
    private let kind: PlaceKind
    private let clock: TimeMap
    private let instant: Double
    private let scale: Double
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
        let below = style.flatMap(theme.value(at:)).map { reader.value(of: $0, as: structure) }
        let written = property?.written.map { reader.value(of: $0, as: structure) }
        let keyframes = (property?.keyframes ?? []).map { keyframe in
            PropertyKeyframe(
                index: keyframe.index,
                at: clock.sequenceTime(ofClipTime: keyframe.at),
                value: reader.value(of: keyframe.value, as: structure),
                ease: keyframe.ease
            )
        }

        let own = try builder.ownLayer(written: written, keyframes: keyframes, as: structure, place: place)
        guard let merged = try merger.merge([below, own], as: structure, place: place), merged != .off else {
            return .off
        }

        do {
            let given = try merger.merge([merged] + keyframes.map(\.value), as: structure, place: place) ?? merged
            try merger.checkRequired(in: given, as: structure, place: place)
        } catch let LookError.missingLeaf(_, missing) {
            let layer = below == .off ? style.map { path in
                theme.place(of: path.reduce(Place.root) { $0.appending(key: $1) })
            } : nil
            throw ResolveError.missingLookLeaf(place: place, kind: kind, key: missing, layer: layer)
        }

        let completed = try defaults.map { defaults in
            try merger.merge(reader.value(of: defaults, as: structure), merged, as: structure, place: place)
        } ?? merged

        return try builder.timed(
            completed,
            written: written,
            keyframes: keyframes,
            as: structure,
            instant: instant,
            place: place,
            leaf: leaf(_:kind:place:)
        )
    }

    // MARK: - Private
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

        case .number, .name, .boolean, .file:
            return .number((value.numberValue ?? 0) * length)
        }
    }
}
