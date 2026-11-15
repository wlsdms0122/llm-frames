//
//  CropConformer.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Conforms a crop to the aspect ratio of the content rect about its centre: `fit` grows it until the written region
// fits inside, and `fill` shrinks it until it lies inside the written region.
struct CropConformer: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func conformed(
        _ crop: Rectangle,
        to content: Rectangle,
        by conform: Conform
    ) -> Rectangle {
        let aspect = content.width / content.height
        let isWider = crop.width / crop.height > aspect
        let keepsWidth = conform == .fit ? isWider : !isWider

        return keepsWidth
            ? Rectangle(center: crop.center, width: crop.width, height: crop.width / aspect)
            : Rectangle(center: crop.center, width: crop.height * aspect, height: crop.height)
    }

    // Where a rectangle of the media lands in the content rect, once the conformed crop fills it.
    func output(
        of rectangle: Rectangle,
        crop: Rectangle,
        content: Rectangle
    ) -> Rectangle {
        let scale = content.width / crop.width

        return Rectangle(
            x: content.x + (rectangle.x - crop.x) * scale,
            y: content.y + (rectangle.y - crop.y) * scale,
            width: rectangle.width * scale,
            height: rectangle.height * scale
        )
    }

    // MARK: - Private
}
