//
//  ManagedPictureConverter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/20/26.
//

import CoreImage
import Foundation
import Frames

// Renders a decoded image tagged with the colour space its file gives by Core Image's colour management into a colour
// space's image space as half floats, and takes them to working values by that space's formulas: the platform reading
// of a picture no fixed formula converts (FRAMES-23 `transcode`). RGBA with premultiplied alpha, rows top first, at
// depth `halfFloat`.
struct ManagedPictureConverter: Sendable {
    // MARK: - Property
    private let context: CIContext

    // MARK: - Initializer
    init() {
        context = CIContext(options: [.cacheIntermediates: false])
    }

    // MARK: - Public
    func picture(
        from image: CIImage,
        in colorSpace: ColorSpace
    ) -> Bitmap {
        let placed = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let width = Int(placed.extent.width.rounded())
        let height = Int(placed.extent.height.rounded())
        var halves = [Float16](repeating: 0, count: width * height * 4)
        halves.withUnsafeMutableBytes { buffer in
            context.render(
                placed,
                toBitmap: buffer.baseAddress!,
                rowBytes: width * 8,
                bounds: CGRect(x: 0, y: 0, width: width, height: height),
                format: .RGBAh,
                colorSpace: colorSpace.imageSpace
            )
        }

        let conversion = ColorConversion(space: colorSpace)
        var pixels = halves.map(Float.init)
        pixels.convertColors(width: width) { conversion.working($0) }
        let working = pixels.map(Float16.init)

        return Bitmap(
            width: width,
            height: height,
            depth: .halfFloat,
            bytesPerRow: width * 8,
            pixels: working.withUnsafeBytes { Data($0) }
        )
    }

    // MARK: - Private
}
