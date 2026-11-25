//
//  Picture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A picture of `size` in its own pixels, which a crop and a box are found in. `name` names it in messages, as the
// document wrote it. `colorSpace` is the space a media file's pictures are read in where the clip writes one, so the
// tracker reads it as the renderer does.
struct Picture: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let size: Size
    let colorSpace: ColorSpace?

    var bounds: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // MARK: - Initializer
    init(
        name: String,
        size: Size,
        colorSpace: ColorSpace? = nil
    ) {
        self.name = name
        self.size = size
        self.colorSpace = colorSpace
    }

    // MARK: - Public
    // MARK: - Private
}
