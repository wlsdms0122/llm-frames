//
//  ResolvedDrawingContent+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a drawing step draws, its picture's files and its text's fonts pinned.
extension ResolvedDrawingContent {
    // MARK: - Property
    // MARK: - Initializer
    init(
        content: DrawingContent,
        hashes: any FileHashProvider
    ) throws {
        switch content {
        case let .picture(picture, crop, frame):
            self = .picture(try ResolvedDrawnPicture(picture: picture, hashes: hashes), crop: crop, frame: frame)

        case let .fill(rectangle, color):
            self = .fill(rectangle, color: color)

        case let .box(rectangle, width, radius, color):
            self = .box(rectangle, width: width, radius: radius, color: color)

        case let .dim(rectangle, color):
            self = .dim(rectangle, color: color)

        case let .arrow(tail, tip, width, head, color):
            self = .arrow(tail: tail, tip: tip, width: width, head: head, color: color)

        case let .adjustment(operations, area):
            self = .adjustment(
                try operations.map { try ResolvedFilterOperation(operation: $0, hashes: hashes) },
                area: area
            )

        case let .text(layout, frame):
            self = .text(try ResolvedText(layout: layout, hashes: hashes), frame: frame)

        case let .border(rectangle, width, color):
            self = .border(rectangle, width: width, color: color)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
