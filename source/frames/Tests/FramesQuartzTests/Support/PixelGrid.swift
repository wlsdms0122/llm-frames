//
//  PixelGrid.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Foundation

// A small test picture of float RGBA with premultiplied alpha, sRGB encoded, rows top first, which a test builds
// pixel by pixel and reads back from an image Core Image renders.
struct PixelGrid {
    // MARK: - Property
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    // The quartz renderer's working space: sRGB encoded, in floats.
    static let context = CIContext(options: [.workingColorSpace: colorSpace, .workingFormat: CIFormat.RGBAf])

    let width: Int
    let height: Int
    let pixels: [Float]

    var image: CIImage {
        CIImage(
            bitmapData: pixels.withUnsafeBufferPointer { Data(buffer: $0) },
            bytesPerRow: width * 16,
            size: CGSize(width: width, height: height),
            format: .RGBAf,
            colorSpace: Self.colorSpace
        )
    }

    // MARK: - Initializer
    init(
        width: Int,
        height: Int,
        pixels: [Float]
    ) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    // `color` is unpremultiplied red, green, blue and alpha.
    init(
        width: Int,
        height: Int,
        color: [Float]
    ) {
        let premultiplied = [color[0] * color[3], color[1] * color[3], color[2] * color[3], color[3]]

        self.init(width: width, height: height, pixels: Array([[Float]](repeating: premultiplied, count: width * height).joined()))
    }

    // Renders `image` over its extent.
    init(rendering image: CIImage) {
        let extent = image.extent
        let width = Int(extent.width)
        let height = Int(extent.height)
        var pixels = [Float](repeating: 0, count: width * height * 4)
        Self.context.render(
            image,
            toBitmap: &pixels,
            rowBytes: width * 16,
            bounds: extent,
            format: .RGBAf,
            colorSpace: Self.colorSpace
        )

        self.init(width: width, height: height, pixels: pixels)
    }

    // MARK: - Public
    // The premultiplied red, green, blue and alpha at `column`, `row` from the top left.
    func pixel(
        column: Int,
        row: Int
    ) -> [Float] {
        let start = (row * width + column) * 4

        return Array(pixels[start..<start + 4])
    }

    // The unpremultiplied red, green and blue, and alpha.
    func color(
        column: Int,
        row: Int
    ) -> [Float] {
        let pixel = pixel(column: column, row: row)
        guard pixel[3] > 0 else { return [0, 0, 0, 0] }

        return [pixel[0] / pixel[3], pixel[1] / pixel[3], pixel[2] / pixel[3], pixel[3]]
    }

    // MARK: - Private
}
