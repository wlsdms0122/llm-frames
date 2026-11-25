//
//  OwnSpace+Resolved.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

extension OwnSpace {
    // MARK: - Property
    // MARK: - Initializer
    // A clip's own space read back from a resolved entry, which writes a box shape's and a box null's geometry as `box`.
    init(content: ResolvedClipContent) {
        switch content {
        case .picture(.media, _):
            self = .media

        case .picture(.title, _):
            self = .box

        case let .picture(.shape(shape), _):
            if case .box = shape.geometry { self = .box } else { self = .parent }

        case .picture(.adjustment, _):
            self = .parent

        case let .null(null):
            if case .box = null.geometry { self = .box } else { self = .parent }
        }
    }

    // MARK: - Public
    // MARK: - Private
}
