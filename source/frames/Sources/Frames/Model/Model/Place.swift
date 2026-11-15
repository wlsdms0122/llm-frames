//
//  Place.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct Place: Hashable, CustomStringConvertible, Sendable {
    // MARK: - Property
    static let root = Place(components: [])

    let components: [PlaceComponent]

    var description: String {
        guard !components.isEmpty else { return "top level" }

        return components.enumerated()
            .map { offset, component in
                switch component {
                case let .key(key):
                    offset == 0 ? key : ".\(key)"

                case let .index(index, id):
                    id.map { "[\(index)]#\($0)" } ?? "[\(index)]"
                }
            }
            .joined()
    }

    // MARK: - Initializer
    init(components: [PlaceComponent]) {
        self.components = components
    }

    // MARK: - Public
    func appending(key: String) -> Place {
        Place(components: components + [.key(key)])
    }

    func appending(index: Int, id: String? = nil) -> Place {
        Place(components: components + [.index(index, id: id)])
    }

    // MARK: - Private
}
