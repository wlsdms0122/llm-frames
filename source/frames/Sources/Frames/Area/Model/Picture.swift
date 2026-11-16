//
//  Picture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What an area is found in: a picture of `size` in its own pixels, from `source`. `name` names it in messages, as the
// document wrote it.
struct Picture: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let source: PictureSource
    let size: Size

    var bounds: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // MARK: - Initializer
    init(
        name: String,
        source: PictureSource,
        size: Size
    ) {
        self.name = name
        self.source = source
        self.size = size
    }

    // MARK: - Public
    // MARK: - Private
}
