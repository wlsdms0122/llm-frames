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

// A transparent half float premultiplied bitmap context of whole pixels in the form of the working values its list's
// `compositing` names, set up as the display list's coordinates: origin at the top left, y pointing down. What is
// drawn into it is converted to its form, and what Core Image computes for it is computed in that form.
final class FrameContext {
    // MARK: - Property
    let context: CGContext
    let width: Int
    let height: Int
    let compositing: Compositing

    var bounds: CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }

    // MARK: - Initializer
    init(
        width: Int,
        height: Int,
        compositing: Compositing
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
                space: WorkingSpace.colorSpace(of: compositing),
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
        self.compositing = compositing
    }

    convenience init(
        holding size: Size,
        compositing: Compositing
    ) throws {
        try self.init(
            width: Int(size.width.rounded(.up)),
            height: Int(size.height.rounded(.up)),
            compositing: compositing
        )
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
        let rendered = try Self.cgImage(of: image, in: bounds, compositing: compositing)

        context.saveGState()
        context.resetClip()
        context.setBlendMode(.copy)
        context.drawUpright(rendered, in: bounds)
        context.restoreGState()
    }

    // The frame as a bitmap of encoded working values: the context's own pixels in the encoded form, and in the
    // linear form converted to the encoded one.
    func bitmap() throws -> Bitmap {
        guard compositing == .linear else { return Self.bitmap(of: context) }

        let encoded = try FrameContext(width: width, height: height, compositing: .encoded)
        encoded.context.setBlendMode(.copy)
        encoded.context.drawUpright(try image(), in: bounds)

        return Self.bitmap(of: encoded.context)
    }

    // The image's pixels inside `extent`, in Core Image's coordinates, computed in the form `compositing` names and
    // held in it.
    static func cgImage(
        of image: CIImage,
        in extent: CGRect,
        compositing: Compositing
    ) throws -> CGImage {
        guard
            let rendered = WorkingSpace.context(of: compositing).createCGImage(
                image,
                from: extent,
                format: .RGBAh,
                colorSpace: WorkingSpace.colorSpace(of: compositing)
            )
        else {
            throw QuartzError.unrenderedImage
        }

        return rendered
    }

    // MARK: - Private
    private static func bitmap(of context: CGContext) -> Bitmap {
        Bitmap(
            width: context.width,
            height: context.height,
            depth: .halfFloat,
            bytesPerRow: context.bytesPerRow,
            pixels: Data(bytes: context.data!, count: context.bytesPerRow * context.height)
        )
    }
}
