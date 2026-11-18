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
        case .media:
            self = .media

        case .title:
            self = .box

        case let .shape(shape):
            self = shape.isPlacedByBox ? .box : .parent

        case .adjust:
            self = .parent
        }
    }

    // MARK: - Public
    // MARK: - Private
}
