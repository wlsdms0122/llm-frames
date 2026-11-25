//
//  Pixels.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The pixels of a picture one role hands another (FRAMES-21 Pictures): a bitmap in memory, or a surface of working
// values that a GPU wrote and any reader reads as the same bytes. A decoder gives a surface only for working values it
// converted on the GPU, and a bitmap for every other picture.
package enum Pixels: Sendable {
    case bitmap(Bitmap)
    case surface(PictureSurface)

    // MARK: - Property
    // The picture's pixels as a bitmap, a surface's read where they lie, with no copy and no conversion.
    package var bitmap: Bitmap {
        switch self {
        case let .bitmap(bitmap):
            bitmap

        case let .surface(surface):
            surface.bitmap
        }
    }

    package var width: Int {
        switch self {
        case let .bitmap(bitmap):
            bitmap.width

        case let .surface(surface):
            surface.width
        }
    }

    package var height: Int {
        switch self {
        case let .bitmap(bitmap):
            bitmap.height

        case let .surface(surface):
            surface.height
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
