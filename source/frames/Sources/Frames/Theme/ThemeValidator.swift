//
//  ThemeValidator.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct ThemeValidator: Sendable {
    // MARK: - Property
    private let checker = KeyChecker()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func checkKeys(of layer: JSONValue) throws {
        try checker.check(layer, as: ThemeKeyTable.theme)
    }

    // References are checked on the merged theme, since a layer may name a colour or style that a weaker layer holds.
    func checkReferences(in theme: JSONValue) throws {
        let object = theme.objectValue ?? JSONObject()
        let colors = Set(object["colors"]?.objectValue?.keys ?? [])
        try walk(theme, as: .object(ThemeKeyTable.theme), place: .root, kind: ThemeKeyTable.theme.kind, colors: colors)

        let styles = Set(object["styles"]?.objectValue?.keys ?? [])
        let titlePlace = Place.root.appending(key: "defaults").appending(key: "animation").appending(key: "title")
        let titles = object["defaults"]?.objectValue?["animation"]?.objectValue?["title"]?.objectValue?.keys ?? []
        for name in titles where !styles.contains(name) {
            throw ThemeError.unknownStyle(
                place: titlePlace.appending(key: name),
                kind: ThemeKeyTable.titleAnimationKind,
                name: name
            )
        }
    }

    // The defaults of a merged theme. Only a theme merged over something other than the base theme can lack one, and
    // that stops where it is missing. A preset a default names must be there whether or not a clip takes it.
    func defaults(
        in theme: JSONValue,
        presets: any PresetProvider
    ) throws -> ThemeDefaults {
        let place = Place.root.appending(key: "defaults")
        let defaults = theme.objectValue?["defaults"]?.objectValue ?? JSONObject()
        let animationPlace = place.appending(key: "animation")
        let animation = defaults["animation"]?.objectValue ?? JSONObject()
        let titlePlace = animationPlace.appending(key: "title")
        let titles = animation["title"]?.objectValue ?? JSONObject()
        try checkFilter(defaults["filter"], place: place.appending(key: "filter"), presets: presets)

        return ThemeDefaults(
            transition: try transitionChoice(in: defaults, place: place, presets: presets),
            titleAnimations: Dictionary(
                try titles.members.map { member in
                    let choice = try animationChoice(
                        member.key,
                        in: titles,
                        place: titlePlace,
                        kind: ThemeKeyTable.titleAnimationKind,
                        presets: presets
                    )
                    return (member.key, choice)
                },
                uniquingKeysWith: { first, _ in first }
            ),
            shapeAnimation: try animationChoice(
                "shape",
                in: animation,
                place: animationPlace,
                kind: ThemeKeyTable.animationDefaults.kind,
                presets: presets
            ),
            mediaAnimation: try animationChoice(
                "media",
                in: animation,
                place: animationPlace,
                kind: ThemeKeyTable.animationDefaults.kind,
                presets: presets
            ),
            adjustAnimation: try animationChoice(
                "adjust",
                in: animation,
                place: animationPlace,
                kind: ThemeKeyTable.animationDefaults.kind,
                presets: presets
            )
        )
    }

    // MARK: - Private
    private func transitionChoice(
        in defaults: JSONObject,
        place: Place,
        presets: any PresetProvider
    ) throws -> TransitionChoice {
        let kind = ThemeKeyTable.defaults.kind
        let choice = try choice(
            "transition",
            in: defaults,
            place: place,
            kind: kind,
            reading: TransitionChoice.init(value:)
        )

        switch choice {
        case .cut:
            break

        case let .preset(name), let .timed(name, _):
            guard try presets.transition(named: name) != nil else {
                throw ThemeError.unknownPreset(
                    place: place.appending(key: "transition"),
                    kind: kind,
                    presetKind: "transition",
                    name: name
                )
            }
        }

        return choice
    }

    // A filter default is one name or a list of them, and `none` names no preset.
    private func checkFilter(
        _ value: JSONValue?,
        place: Place,
        presets: any PresetProvider
    ) throws {
        let names: [(name: String, place: Place)] = switch value {
        case let .string(name):
            [(name, place)]

        case let .array(elements):
            elements.enumerated().compactMap { index, element in
                element.stringValue.map { ($0, place.appending(index: index)) }
            }

        default:
            []
        }

        for (name, place) in names where name != "none" {
            guard try presets.filter(named: name) != nil else {
                throw ThemeError.unknownPreset(
                    place: place,
                    kind: ThemeKeyTable.defaults.kind,
                    presetKind: "filter",
                    name: name
                )
            }
        }
    }

    // `none` on a side of a split names no preset.
    private func animationChoice(
        _ key: String,
        in object: JSONObject,
        place: Place,
        kind: String,
        presets: any PresetProvider
    ) throws -> AnimationChoice {
        let choice = try choice(key, in: object, place: place, kind: kind, reading: AnimationChoice.init(value:))
        let names: [String] = switch choice {
        case .none:
            []

        case let .preset(name):
            [name]

        case let .split(entrance, exit):
            [entrance, exit]
        }

        for name in names where name != "none" {
            guard try presets.animation(named: name) != nil else {
                throw ThemeError.unknownPreset(
                    place: place.appending(key: key),
                    kind: kind,
                    presetKind: "animation",
                    name: name
                )
            }
        }

        return choice
    }

    private func choice<Choice>(
        _ key: String,
        in object: JSONObject,
        place: Place,
        kind: String,
        reading read: (JSONValue) -> Choice?
    ) throws -> Choice {
        guard let choice = object[key].flatMap(read) else {
            throw ModelError.missingKey(place: place, kind: kind, keys: [key])
        }

        return choice
    }

    private func walk(
        _ value: JSONValue,
        as type: ValueType,
        place: Place,
        kind: String,
        colors: Set<String>
    ) throws {
        switch (type, value) {
        case let (.color, .string(name)) where !name.hasPrefix("#"):
            guard colors.contains(name) else {
                throw ThemeError.unknownColor(place: place, kind: kind, name: name)
            }

        case let (.object(table), .object(object)):
            for member in object.members {
                guard let rule = table.rule(named: member.key) else { continue }

                try walk(member.value, as: rule.type, place: place.appending(key: member.key), kind: table.kind, colors: colors)
            }

        case let (.map(valueType, mapKind), .object(object)):
            for member in object.members {
                try walk(member.value, as: valueType, place: place.appending(key: member.key), kind: mapKind, colors: colors)
            }

        case let (.list(elementType), .array(elements)):
            for (index, element) in elements.enumerated() {
                try walk(element, as: elementType, place: place.appending(index: index), kind: kind, colors: colors)
            }

        case let (.oneOf(types), _):
            for type in types {
                try walk(value, as: type, place: place, kind: kind, colors: colors)
            }

        default:
            return
        }
    }
}
