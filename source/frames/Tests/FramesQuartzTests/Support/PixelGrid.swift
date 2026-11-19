//
//  PixelGrid.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Foundation
import Frames
@testable import FramesQuartz

// A small test picture of float RGBA with premultiplied alpha, encoded working values, unbounded, rows top first,
// which a test builds pixel by pixel and reads back from an image Core Image renders in either form of the working
// values, in 32 bit floats.
struct PixelGrid {
    // MARK: - Property
    static let colorSpace = WorkingSpace.encoded

    private static let encodedContext = CIContext(options: [
        .workingColorSpace: WorkingSpace.encoded,
        .workingFormat: CIFormat.RGBAf
    ])
    private static let linearContext = CIContext(options: [
        .workingColorSpace: WorkingSpace.linear,
        .workingFormat: CIFormat.RGBAf
    ])

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

    // Renders `image` over its extent, computed in the form `compositing` names.
    init(
        rendering image: CIImage,
        compositing: Compositing = .encoded
    ) {
        let extent = image.extent
        let width = Int(extent.width)
        let height = Int(extent.height)
        var pixels = [Float](repeating: 0, count: width * height * 4)
        let context = compositing == .linear ? Self.linearContext : Self.encodedContext
        context.render(
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
