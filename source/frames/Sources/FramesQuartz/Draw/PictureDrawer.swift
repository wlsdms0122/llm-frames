//
//  PictureDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Frames

// Draws a picture item in its item's own coordinates: the source region scaled into the destination, filtered at the
// destination's size, masked by its matte, its corners rounded, its border inside the destination's edge and its
// shadow below. A picture with no filter, matte or shadow is drawn straight from its source, so it is resampled once
// on its way to the output.
struct PictureDrawer {
    // MARK: - Property
    private let tables: LookUpTableCache

    // MARK: - Initializer
    init(tables: LookUpTableCache) {
        self.tables = tables
    }

    // MARK: - Public
    func draw(
        _ item: PictureItem,
        source: CGImage,
        matte: CGImage?,
        seed: Int,
        in context: CGContext
    ) throws {
        let destination = item.destination
        let region = item.rectangle ?? Rectangle(
            x: 0,
            y: 0,
            width: Double(source.width),
            height: Double(source.height)
        )
        guard destination.width > 0, destination.height > 0, region.width > 0, region.height > 0 else { return }

        guard !item.filter.isEmpty || item.matte != nil || item.shadow != nil else {
            framed(
                source,
                placed: placement(of: region, in: destination, size: source),
                item: item,
                destination: destination,
                in: context
            )

            return
        }

        let size = Size(width: destination.width, height: destination.height)
        let local = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let scaled = try FrameContext(holding: size)
        scaled.context.clip(to: CGRect(local))
        scaled.context.drawUpright(source, in: placement(of: region, in: local, size: source))

        var picture = try scaled.ciImage()
        let extent = picture.extent
        picture = try FilterChain(tables: tables).apply(item.filter, to: picture, seed: seed).cropped(to: extent)
        if let pictureMatte = item.matte, let matte {
            picture = try MatteApplier().apply(pictureMatte, frame: matte, to: picture, size: size)
        }

        let finished = try FrameContext(holding: size)
        framed(
            try FrameContext.cgImage(of: picture, in: extent),
            placed: scaled.bounds,
            item: item,
            destination: local,
            in: finished.context
        )
        let image = try finished.image()
        let bounds = CGRect(x: destination.x, y: destination.y, width: extent.width, height: extent.height)
        if let shadow = item.shadow {
            try draw(shadow, of: image, at: bounds, in: context)
        }
        context.drawUpright(image, in: bounds)
    }

    // MARK: - Private
    // Where the whole source lands when its region fills the destination.
    private func placement(
        of region: Rectangle,
        in destination: Rectangle,
        size source: CGImage
    ) -> CGRect {
        let scaleX = destination.width / region.width
        let scaleY = destination.height / region.height

        return CGRect(
            x: destination.x - region.x * scaleX,
            y: destination.y - region.y * scaleY,
            width: Double(source.width) * scaleX,
            height: Double(source.height) * scaleY
        )
    }

    // The image cut to the destination with its corners rounded, and the border over it.
    private func framed(
        _ image: CGImage,
        placed: CGRect,
        item: PictureItem,
        destination: Rectangle,
        in context: CGContext
    ) {
        context.saveGState()
        context.addPath(RoundedOutline(rectangle: destination, radius: item.radius).path)
        context.clip()
        context.drawUpright(image, in: placed)
        context.restoreGState()

        guard let border = item.border else { return }

        // The border's outer edge follows the rounded corners of the destination.
        let geometry = StrokeItem(border: destination, width: border.width, color: border.color)
        let stroke = StrokeItem(
            rectangle: geometry.rectangle,
            radius: max(0, item.radius - border.width / 2),
            width: geometry.width,
            color: geometry.color
        )
        ShapeDrawer().draw(stroke, in: context)
    }

    // The picture's alpha in the shadow's colour, blurred with the shadow's radius as standard deviation and moved by
    // its offset, drawn below the picture at `bounds`.
    private func draw(
        _ shadow: MediaShadow,
        of image: CGImage,
        at bounds: CGRect,
        in context: CGContext
    ) throws {
        let shape = CIImage(cgImage: image)
        let reach = (shadow.radius * 3).rounded(.up) + 1
        var tinted = CIImage(color: CIColor(cgColor: shadow.color.cgColor))
            .cropped(to: shape.extent)
            .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: shape])
        if shadow.radius > 0 {
            tinted = tinted.applyingGaussianBlur(sigma: shadow.radius)
        }
        let moved = tinted
            .cropped(to: shape.extent.insetBy(dx: -reach, dy: -reach))
            .transformed(by: CGAffineTransform(translationX: shadow.offset.x, y: -shadow.offset.y))
        let extent = moved.extent.integral
        let rendered = try FrameContext.cgImage(of: moved, in: extent)

        context.drawUpright(
            rendered,
            in: CGRect(
                x: bounds.minX + extent.minX,
                y: bounds.minY + shape.extent.maxY - extent.maxY,
                width: extent.width,
                height: extent.height
            )
        )
    }
}
