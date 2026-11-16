//
//  ShapeForm.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A shape as written. An arrow points from the side the document names, since the engine has no rule to choose one.
enum ShapeForm: Equatable, Sendable {
    case box
    case fill
    case dim
    case arrow(Side)

    // MARK: - Property
    var kind: ShapeKind {
        switch self {
        case .box:
            .box

        case .fill:
            .fill

        case .dim:
            .dim

        case .arrow:
            .arrow
        }
    }

    // MARK: - Initializer
    // Reads the `shape` and `side` of a shape operation or clip, nil for an object that holds no shape.
    init?(object: JSONObject) {
        guard let kind = object["shape"]?.stringValue.flatMap(ShapeKind.init(rawValue:)) else { return nil }

        switch kind {
        case .box:
            self = .box

        case .fill:
            self = .fill

        case .dim:
            self = .dim

        case .arrow:
            guard let side = object["side"]?.stringValue.flatMap(Side.init(rawValue:)) else { return nil }

            self = .arrow(side)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
