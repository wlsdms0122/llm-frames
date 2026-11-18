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
// destination's size, masked by its matte, its corners rounded and its border inside the destination's edge. A
// picture with no filter or matte is drawn straight from its source, so it is resampled once on its way to the
// output.
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

        guard !item.filter.isEmpty || item.matte != nil else {
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
        let bounds = CGRect(x: destination.x, y: destination.y, width: extent.width, height: extent.height)
        context.drawUpright(try finished.image(), in: bounds)
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
        context.addPath(PathOutline(.rect(destination, radius: item.radius)).path)
        context.clip()
        context.drawUpright(image, in: placed)
        context.restoreGState()

        guard let border = item.border else { return }

        // A stroke centred `width / 2` in from the destination's edge, so its outer edge follows the destination's
        // rounded corners.
        let half = border.width / 2
        let edge = Rectangle(
            x: destination.x + half,
            y: destination.y + half,
            width: destination.width - border.width,
            height: destination.height - border.width
        )
        let stroke = PathStroke(width: border.width, color: border.color, join: .miter, cap: .butt, start: .none, end: .none)
        let path = PathItem(geometry: .rect(edge, radius: max(0, item.radius - half)), fill: nil, stroke: stroke)
        PathDrawer().draw(path, in: context)
    }
}
