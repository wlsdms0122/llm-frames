//
//  OwnSpace+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

extension OwnSpace {
    // MARK: - Property
    // MARK: - Initializer
    init(content: ClipContent) {
        switch content {
        // An audio clip draws nothing and is no parent, so nothing reads its space.
        case .media, .audio:
            self = .media

        case .title:
            self = .box

        case let .shape(shape):
            self = shape.isPlacedByBox ? .box : .parent

        case .adjust:
            self = .parent

        case let .null(null):
            self = null.isPlacedByBox ? .box : .parent
        }
    }

    // MARK: - Public
    // MARK: - Private
}
