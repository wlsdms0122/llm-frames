//
//  PositionForm.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A position as written: a point, or `{area, point}`, the named point of an area.
enum PositionForm: Equatable, Sendable {
    case point(Point)
    case area(AreaForm, point: String)

    // MARK: - Property
    var isFoundByText: Bool {
        if case let .area(area, _) = self { area.isFoundByText } else { false }
    }

    // MARK: - Initializer
    init?(value: JSONValue) {
        if let numbers = value.arrayValue?.compactMap(\.numberValue), numbers.count == 2 {
            self = .point(Point(x: numbers[0], y: numbers[1]))
            return
        }
        guard
            let object = value.objectValue,
            let area = object["area"].flatMap(AreaForm.init(value:)),
            let point = object["point"]?.stringValue
        else {
            return nil
        }

        self = .area(area, point: point)
    }

    // MARK: - Public
    // MARK: - Private
}
