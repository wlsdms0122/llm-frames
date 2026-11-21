//
//  CropForm.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A crop as written: an area of the media, or `{scale: s}`, a centred region `1/s` the size of the picture.
enum CropForm: Equatable, Sendable {
    case area(AreaForm)
    case scale(Double)

    // MARK: - Property
    var isFoundByText: Bool {
        if case let .area(area) = self { area.isFoundByText } else { false }
    }

    // MARK: - Initializer
    init?(value: JSONValue) {
        if let scale = value.objectValue?["scale"]?.numberValue {
            self = .scale(scale)
            return
        }
        guard let area = AreaForm(value: value) else { return nil }

        self = .area(area)
    }

    // MARK: - Public
    // MARK: - Private
}
