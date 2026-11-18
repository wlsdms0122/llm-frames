//
//  OwnSpace+Resolved.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

extension OwnSpace {
    // MARK: - Property
    // MARK: - Initializer
    // A clip's own space read back from a resolved entry, which writes a box shape's geometry as `box`.
    init(content: ResolvedClipContent) {
        switch content {
        case .media:
            self = .media

        case .title:
            self = .box

        case let .shape(shape):
            if case .box = shape.geometry { self = .box } else { self = .parent }

        case .adjustment:
            self = .parent
        }
    }

    // MARK: - Public
    // MARK: - Private
}
