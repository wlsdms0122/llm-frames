//
//  Place.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `file` names a file other than the document, as it was referred to, and the components are a path from that file.
struct Place: Hashable, CustomStringConvertible, Sendable {
    // MARK: - Property
    static let root = Place(components: [])

    let file: String?
    let components: [PlaceComponent]

    var description: String {
        guard let file else { return path }

        return "\(file): \(path)"
    }

    private var path: String {
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
    init(
        file: String? = nil,
        components: [PlaceComponent]
    ) {
        self.file = file
        self.components = components
    }

    // MARK: - Public
    func appending(key: String) -> Place {
        Place(file: file, components: components + [.key(key)])
    }

    func appending(index: Int, id: String? = nil) -> Place {
        Place(file: file, components: components + [.index(index, id: id)])
    }

    // The place of a path written from this place, such as a key of a theme layer written here.
    func appending(_ path: Place) -> Place {
        Place(file: file, components: components + path.components)
    }

    // MARK: - Private
}
