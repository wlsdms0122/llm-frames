//
//  PlaceKind.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What a message names in parentheses after its place, in the words of the key tables: a clip's kind once its media
// is known, the clip of its place before that, the sequence, an image or layout document, a layout item, an image
// operation by its kind, or a shape operation by its shape.
enum PlaceKind: Equatable, Sendable {
    case clip(ClipKind)
    case genericClip(ClipPlace)
    case sequence
    case image
    case layout
    case layoutItem
    case operation(ImageOperationKind)
    case shape(ShapeKind)

    // MARK: - Property
    var label: String {
        switch self {
        case let .clip(kind):
            kind.label

        case let .genericClip(clipPlace):
            clipPlace.label

        case .sequence:
            DocumentKeyTable.sequence.kind

        case .image:
            DocumentKeyTable.image.kind

        case .layout:
            DocumentKeyTable.layout.kind

        case .layoutItem:
            DocumentKeyTable.layoutItem.kind

        case let .operation(kind):
            kind.rawValue

        case let .shape(shape):
            shape.rawValue
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
