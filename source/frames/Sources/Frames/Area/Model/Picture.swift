//
//  Picture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What an area is found in: a picture of `size` in its own pixels. `file` is the media file or image sequence
// directory text is recognised in, and nil for a picture that is drawn, not read. `name` names it in messages, as the
// document wrote it.
struct Picture: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let file: String?
    let size: Size

    var bounds: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // MARK: - Initializer
    init(
        name: String,
        file: String?,
        size: Size
    ) {
        self.name = name
        self.file = file
        self.size = size
    }

    // MARK: - Public
    // MARK: - Private
}
