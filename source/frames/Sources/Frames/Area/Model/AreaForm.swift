//
//  AreaForm.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A place in a picture as a document writes it: a rectangle, text found by OCR in one of the finding forms, which
// grows by its `padding` in the pixels of the picture searched, or the box of another clip, which grows by its
// `padding` as a theme length.
enum AreaForm: Equatable, Sendable {
    case rectangle(Rectangle)
    case text(String, nth: Int?, padding: Double)
    case range(from: String, fromNth: Int?, to: String, toNth: Int?, padding: Double)
    case clip(String, padding: Double)

    // MARK: - Property
    var isFoundByText: Bool {
        switch self {
        case .rectangle, .clip:
            false

        case .text, .range:
            true
        }
    }

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
        guard let object = value.objectValue else { return nil }

        let padding = object["padding"]?.numberValue ?? 0
        if let clip = object["clip"]?.stringValue {
            self = .clip(clip, padding: padding)
        } else if let text = object["text"]?.stringValue {
            self = .text(text, nth: object["nth"]?.numberValue.flatMap { Int(exactly: $0) }, padding: padding)
        } else if let from = object["from"]?.stringValue, let to = object["to"]?.stringValue {
            self = .range(
                from: from,
                fromNth: object["fromNth"]?.numberValue.flatMap { Int(exactly: $0) },
                to: to,
                toNth: object["toNth"]?.numberValue.flatMap { Int(exactly: $0) },
                padding: padding
            )
        } else {
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
