//
//  RenderedPicture.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation
import ImageIO

// A frame `still` wrote, read back as opaque sRGB with 8 bits per component. The frame is found as the first pixel
// along the diagonal from the top left that differs from the sheet's background there, so a frame whose top left
// pixel is the background's colour is not found.
struct RenderedPicture {
    // MARK: - Property
    private let width: Int
    private let bytes: [UInt8]
    private let origin: Int

    // MARK: - Initializer
    init(contentsOf path: String) throws {
        guard
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let isDrawn = bytes.withUnsafeMutableBytes { buffer in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                )
            else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

            return true
        }
        guard isDrawn else { throw CocoaError(.fileReadCorruptFile) }

        let background = Array(bytes[0..<3])
        let origin = (0..<min(width, height)).first { index in
            let start = (index * width + index) * 4
            return Array(bytes[start..<start + 3]) != background
        }

        self.width = width
        self.bytes = bytes
        self.origin = origin ?? 0
    }

    // MARK: - Public
    // The red, green and blue at `column`, `row` from the frame's top left, from 0 to 255.
    func color(
        column: Int,
        row: Int
    ) -> (red: Double, green: Double, blue: Double) {
        let start = ((origin + row) * width + origin + column) * 4

        return (Double(bytes[start]), Double(bytes[start + 1]), Double(bytes[start + 2]))
    }

    // MARK: - Private
}
