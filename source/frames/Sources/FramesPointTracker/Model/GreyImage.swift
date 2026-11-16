//
//  GreyImage.swift
//  FramesPointTracker
//
//  Created by JSilver on 11/16/26.
//

import Frames

// Grey values from 0 to 1, row by row from the top left. A pixel outside the picture it was read from is NaN and
// takes no part in a comparison.
struct GreyImage: Sendable {
    // MARK: - Property
    let width: Int
    let height: Int
    let values: [Float]

    // MARK: - Initializer
    init(
        width: Int,
        height: Int,
        values: [Float]
    ) {
        self.width = width
        self.height = height
        self.values = values
    }

    // The luma of `picture`, its sRGB encoded components weighted as Rec. 709 weights them. Its colour is taken
    // premultiplied, as over black.
    init(picture: Bitmap) {
        let componentBytes = picture.depth.bitsPerComponent / 8
        let maximum = Float((1 << picture.depth.bitsPerComponent) - 1)
        var values = [Float](repeating: 0, count: picture.width * picture.height)
        picture.pixels.withUnsafeBytes { pixels in
            values.withUnsafeMutableBufferPointer { values in
                for y in 0..<picture.height {
                    for x in 0..<picture.width {
                        let offset = y * picture.bytesPerRow + x * 4 * componentBytes
                        let red = Self.component(of: pixels, at: offset, depth: picture.depth)
                        let green = Self.component(of: pixels, at: offset + componentBytes, depth: picture.depth)
                        let blue = Self.component(of: pixels, at: offset + 2 * componentBytes, depth: picture.depth)
                        values[y * picture.width + x] = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / maximum
                    }
                }
            }
        }

        self.init(width: picture.width, height: picture.height, values: values)
    }

    // MARK: - Public
    func value(
        x: Int,
        y: Int
    ) -> Float {
        values[y * width + x]
    }

    // The `width` by `height` pixels from `column` and `row`, which lie in the image.
    func cropped(
        column: Int,
        row: Int,
        width: Int,
        height: Int
    ) -> GreyImage {
        var cropped: [Float] = []
        cropped.reserveCapacity(width * height)
        for y in row..<(row + height) {
            let start = y * self.width + column
            cropped.append(contentsOf: values[start..<(start + width)])
        }

        return GreyImage(width: width, height: height, values: cropped)
    }

    // Half the size, each pixel the mean of the two by two it covers that lie inside the picture.
    func halved() -> GreyImage {
        let halfWidth = max(1, width / 2)
        let halfHeight = max(1, height / 2)
        var halved = [Float](repeating: .nan, count: halfWidth * halfHeight)
        values.withUnsafeBufferPointer { values in
            for y in 0..<halfHeight {
                for x in 0..<halfWidth {
                    var sum: Float = 0
                    var count: Float = 0
                    for row in (2 * y)..<min(2 * y + 2, height) {
                        for column in (2 * x)..<min(2 * x + 2, width) {
                            let value = values[row * width + column]
                            guard !value.isNaN else { continue }
                            sum += value
                            count += 1
                        }
                    }
                    if count > 0 { halved[y * halfWidth + x] = sum / count }
                }
            }
        }

        return GreyImage(width: halfWidth, height: halfHeight, values: halved)
    }

    // MARK: - Private
    private static func component(
        of pixels: UnsafeRawBufferPointer,
        at offset: Int,
        depth: BitDepth
    ) -> Float {
        switch depth {
        case .eight:
            Float(pixels[offset])

        case .sixteen:
            Float(pixels.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
        }
    }
}
