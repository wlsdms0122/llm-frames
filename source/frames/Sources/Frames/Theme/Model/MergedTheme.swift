//
//  MergedTheme.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A merged theme with the layers over the base theme it was merged from, weakest first, so that a value of it is
// reported where it was written.
struct MergedTheme: Equatable, Sendable {
    // MARK: - Property
    static let base = MergedTheme(value: BaseTheme.value, layers: [])

    let value: JSONValue
    let layers: [ThemeLayer]

    // MARK: - Initializer
    init(
        value: JSONValue,
        layers: [ThemeLayer]
    ) {
        self.value = value
        self.layers = layers
    }

    // MARK: - Public
    // The strongest layer that holds the path wrote its value, or the last change to it. A path no layer holds is the
    // base theme's.
    func place(of path: Place) -> Place {
        guard let layer = layers.last(where: { holds($0.value, path.components[...]) }) else { return path }

        return layer.place.appending(path)
    }

    // The pack the strongest layer that holds the path is written in, nil for the base theme or a layer in no pack.
    func pack(of path: Place) -> String? {
        layers.last { holds($0.value, path.components[...]) }?.pack
    }

    // MARK: - Private
    private func holds(
        _ value: JSONValue,
        _ components: ArraySlice<PlaceComponent>
    ) -> Bool {
        guard let component = components.first else { return true }

        switch (component, value) {
        case let (.key(key), .object(object)):
            guard let member = object[key] else { return false }

            return holds(member, components.dropFirst())

        case let (.index(index, _), .array(elements)):
            guard elements.indices.contains(index) else { return false }

            return holds(elements[index], components.dropFirst())

        default:
            return false
        }
    }
}
