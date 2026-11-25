//
//  AreaForm.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A place in a picture as a document writes it: a rectangle, or the box of another clip, which grows by its `padding`
// as a theme length.
enum AreaForm: Equatable, Sendable {
    case rectangle(Rectangle)
    case clip(String, padding: Double)

    // MARK: - Property
    var clip: String? {
        guard case let .clip(clip, _) = self else { return nil }

        return clip
    }

    // MARK: - Initializer
    init?(value: JSONValue) {
        if let numbers = value.arrayValue?.compactMap(\.numberValue), numbers.count == 4 {
            self = .rectangle(Rectangle(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]))
            return
        }
        guard let object = value.objectValue, let clip = object["clip"]?.stringValue else { return nil }

        self = .clip(clip, padding: object["padding"]?.numberValue ?? 0)
    }

    // MARK: - Public
    // The rectangle of an area in a picture, where a clip area stops, since it is the box of another clip in the space
    // a clip is drawn in and not a place in the picture.
    func rectangle(
        place: Place,
        kind: String
    ) throws -> Rectangle {
        switch self {
        case let .rectangle(rectangle):
            return rectangle

        case .clip:
            throw AreaError.clipAreaInPicture(place: place, kind: kind)
        }
    }

    // MARK: - Private
}
