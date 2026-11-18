//
//  MaskGeometryForm.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a mask gives its geometry, as written: an area, a box of `width` by `height` centred on `position`, or a path's
// points.
enum MaskGeometryForm: Equatable, Sendable {
    case area(AreaForm)
    case box(width: Double, height: Double, position: PositionForm)
    case points([PositionForm])

    // MARK: - Property
    var isFoundByText: Bool {
        switch self {
        case let .area(area):
            area.isFoundByText

        case let .box(_, _, position):
            position.isFoundByText

        case let .points(points):
            points.contains(where: \.isFoundByText)
        }
    }

    // The key that names the form, which two keyframes of one mask must share.
    var key: String {
        switch self {
        case .area:
            "area"

        case .box:
            "position"

        case .points:
            "points"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
