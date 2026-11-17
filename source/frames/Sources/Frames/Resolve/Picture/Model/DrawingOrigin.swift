//
//  DrawingOrigin.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What drew a drawing step, named as messages name it: its place in the document, continued into a nested document
// from what holds it, its `id`, and its kind. An operation is its kind, a shape by its shape, and the source picture,
// the layout and a layout item are the document parts that draw it.
struct DrawingOrigin: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let kind: PlaceKind

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        kind: PlaceKind
    ) {
        self.place = place
        self.id = id
        self.kind = kind
    }

    init(_ operation: ImageOperation) {
        let kind: PlaceKind = switch operation.content {
        case .crop:
            .operation(.crop)

        case .resize:
            .operation(.resize)

        case .pad:
            .operation(.pad)

        case let .shape(shape, _, _, _):
            .shape(shape.kind)

        case .adjust:
            .operation(.adjust)

        case .title:
            .operation(.title)

        case .banner:
            .operation(.banner)

        case .border:
            .operation(.border)
        }

        self.init(place: operation.place, id: operation.id, kind: kind)
    }

    // MARK: - Public
    // MARK: - Private
}
