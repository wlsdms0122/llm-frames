//
//  Picture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What an area is found in: a picture of `size` in its own pixels, from `source`. `name` names it in messages, as the
// document wrote it. `colorSpace` is the space a media file's pictures are read in where the clip writes one, so the
// providers read it as the renderer does.
struct Picture: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let source: PictureSource
    let size: Size
    let colorSpace: ColorSpace?

    var bounds: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // MARK: - Initializer
    init(
        name: String,
        source: PictureSource,
        size: Size,
        colorSpace: ColorSpace? = nil
    ) {
        self.name = name
        self.source = source
        self.size = size
        self.colorSpace = colorSpace
    }

    // MARK: - Public
    // MARK: - Private
}
