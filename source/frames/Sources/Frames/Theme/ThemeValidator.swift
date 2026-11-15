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
        try walk(theme, as: .object(ThemeKeyTable.theme), place: .root, kind: "theme", colors: colors)

        let styles = Set(object["styles"]?.objectValue?.keys ?? [])
        let titlePlace = Place.root.appending(key: "defaults").appending(key: "animation").appending(key: "title")
        let titles = object["defaults"]?.objectValue?["animation"]?.objectValue?["title"]?.objectValue?.keys ?? []
        for name in titles where !styles.contains(name) {
            throw ThemeError.unknownStyle(place: titlePlace.appending(key: name), name: name)
        }
    }

    // MARK: - Private
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
