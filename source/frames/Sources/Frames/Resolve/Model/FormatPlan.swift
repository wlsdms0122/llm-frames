//
//  FormatPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The output frame of a sequence and its content rect, in output pixels, with how storyline crops fill that rect.
struct FormatPlan: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let content: Rectangle
    let conform: Conform

    var frame: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // MARK: - Initializer
    init(
        size: Size,
        content: Rectangle,
        conform: Conform
    ) {
        self.size = size
        self.content = content
        self.conform = conform
    }

    // MARK: - Public
    // MARK: - Private
}
