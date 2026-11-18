//
//  MaskKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The keys of a mask for each shape it can be: a rect or an ellipse takes a box, by `area` or by `width`, `height` and
// `position`, and only a rect a `radius`, and a path takes `points`. A key its shape does not take stops as an unknown
// key.
enum MaskKeyTable {
    static let box = ["width", "height", "position"]

    static func table(for shape: ShapeKind) -> ObjectTable {
        let geometry: [KeyRule] = switch shape {
        case .rect:
            [area, width, height, position, KeyRule("radius", .nonNegativeNumber)]

        case .ellipse:
            [area, width, height, position]

        case .path:
            [KeyRule("points", .points, isRequired: true)]
        }

        return ObjectTable(
            kind: "\(shape.rawValue) mask",
            rules: [KeyRule("shape", .literal(VocabularyTable.shapes), isRequired: true)] + geometry + [
                KeyRule("feather", .nonNegativeNumber),
                KeyRule("invert", .bool),
                KeyRule("mode", .literal(MaskMode.allCases.map(\.rawValue)))
            ]
        )
    }

    private static let area = KeyRule("area", .area)
    private static let width = KeyRule("width", .positiveNumber)
    private static let height = KeyRule("height", .positiveNumber)
    private static let position = KeyRule("position", AreaKeyTable.point)
}
