//
//  FrameContext.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Foundation
import Frames

// A transparent sixteen bit premultiplied sRGB bitmap context of whole pixels, set up as the display list's
// coordinates: origin at the top left, y pointing down.
final class FrameContext {
    // MARK: - Property
    let context: CGContext
    let width: Int
    let height: Int

    var bounds: CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }

    // MARK: - Initializer
    init(
        width: Int,
        height: Int
    ) throws {
        guard
            width > 0,
            height > 0,
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 16,
                bytesPerRow: 0,
                space: WorkingSpace.colorSpace,
                bitmapInfo: WorkingSpace.bitmapInfo
            )
        else {
            throw QuartzError.unmadeBitmap(width: width, height: height)
        }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        // `.high` maps the first and last pixel centres onto each other, which stretches a scaled picture by up to half
        // a pixel at its edges. `.medium` filters a reduction as smoothly and keeps pixel centres where they belong.
        context.interpolationQuality = .medium
        context.textMatrix = .identity
        context.setAllowsFontSmoothing(false)
        context.setAllowsFontSubpixelQuantization(false)
        context.setShouldSubpixelQuantizeFonts(false)

        self.context = context
        self.width = width
        self.height = height
    }

    // The context that holds a size in whole pixels, a fraction of a pixel rounded up.
    convenience init(holding size: Size) throws {
        try self.init(width: Int(size.width.rounded(.up)), height: Int(size.height.rounded(.up)))
    }

    // MARK: - Public
    func image() throws -> CGImage {
        guard let image = context.makeImage() else { throw QuartzError.unmadeBitmap(width: width, height: height) }

        return image
    }

    // What is drawn so far as a Core Image image, its extent the context's bounds.
    func ciImage() throws -> CIImage {
        CIImage(cgImage: try image())
    }

    // Replaces every pixel with the image's over the context's bounds.
    func replace(with image: CIImage) throws {
        let rendered = try Self.cgImage(of: image, in: bounds)

        context.saveGState()
        context.resetClip()
        context.setBlendMode(.copy)
        context.drawUpright(rendered, in: bounds)
        context.restoreGState()
    }

    func bitmap() -> Bitmap {
        let length = context.bytesPerRow * height

        return Bitmap(
            width: width,
            height: height,
            depth: .sixteen,
            bytesPerRow: context.bytesPerRow,
            pixels: Data(bytes: context.data!, count: length)
        )
    }

    // The image's pixels inside `extent`, in Core Image's coordinates, rendered in the working space.
    static func cgImage(
        of image: CIImage,
        in extent: CGRect
    ) throws -> CGImage {
        guard
            let rendered = WorkingSpace.context.createCGImage(
                image,
                from: extent,
                format: .RGBA16,
                colorSpace: WorkingSpace.colorSpace
            )
        else {
            throw QuartzError.unrenderedImage
        }

        return rendered
    }

    // MARK: - Private
}
