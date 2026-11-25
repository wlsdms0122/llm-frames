//
//  Picture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A picture of `size` in its own pixels, which a crop and a box are found in. `name` names it in messages, as the
// document wrote it.
struct Picture: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let size: Size

    var bounds: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // MARK: - Initializer
    init(
        name: String,
        size: Size
    ) {
        self.name = name
        self.size = size
    }

    // MARK: - Public
    // MARK: - Private
}
