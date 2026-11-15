//
//  AreaForm.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A place in a picture as a document writes it: a rectangle in media pixels, or text found by OCR in one of the
// finding forms.
indirect enum AreaForm: Equatable, Sendable {
    case rectangle(Rectangle)
    case text(String, nth: Int?)
    case range(from: String, fromNth: Int?, to: String, toNth: Int?)
    case band(AreaForm)

    // MARK: - Property
    var isFoundByText: Bool {
        switch self {
        case .rectangle:
            false

        case .text, .range:
            true

        case let .band(inner):
            inner.isFoundByText
        }
    }

    // MARK: - Initializer
    init?(value: JSONValue) {
        if let text = value.stringValue {
            self = .text(text, nth: nil)
            return
        }
        if let numbers = value.arrayValue?.compactMap(\.numberValue), numbers.count == 4 {
            self = .rectangle(Rectangle(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]))
            return
        }
        guard let object = value.objectValue else { return nil }

        if let band = object["band"] {
            guard let inner = AreaForm(value: band) else { return nil }

            self = .band(inner)
        } else if let text = object["text"]?.stringValue {
            self = .text(text, nth: object["nth"]?.numberValue.flatMap { Int(exactly: $0) })
        } else if let from = object["from"]?.stringValue, let to = object["to"]?.stringValue {
            self = .range(
                from: from,
                fromNth: object["fromNth"]?.numberValue.flatMap { Int(exactly: $0) },
                to: to,
                toNth: object["toNth"]?.numberValue.flatMap { Int(exactly: $0) }
            )
        } else {
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
