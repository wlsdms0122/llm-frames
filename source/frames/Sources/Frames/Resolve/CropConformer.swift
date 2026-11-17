//
//  CropConformer.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Conforms a crop to the aspect ratio of the box it fills about its centre: `fit` grows it until the written region
// fits inside, and `fill` shrinks it until it lies inside the written region.
struct CropConformer: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func conformed(
        _ crop: Rectangle,
        to box: Rectangle,
        by conform: Conform
    ) -> Rectangle {
        let aspect = box.width / box.height
        let isWider = crop.width / crop.height > aspect
        let keepsWidth = conform == .fit ? isWider : !isWider

        return keepsWidth
            ? Rectangle(center: crop.center, width: crop.width, height: crop.width / aspect)
            : Rectangle(center: crop.center, width: crop.height * aspect, height: crop.height)
    }

    // Where a rectangle of the media lands in the box, once the conformed crop fills it.
    func output(
        of rectangle: Rectangle,
        crop: Rectangle,
        box: Rectangle
    ) -> Rectangle {
        let scale = box.width / crop.width

        return Rectangle(
            x: box.x + (rectangle.x - crop.x) * scale,
            y: box.y + (rectangle.y - crop.y) * scale,
            width: rectangle.width * scale,
            height: rectangle.height * scale
        )
    }

    // MARK: - Private
}
