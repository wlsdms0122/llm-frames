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
// output. A filtered picture is filtered at the scale the context shows its destination at, its filter's lengths
// scaled with it, so it is as sharp as the source it is drawn from.
struct PictureDrawer {
    // MARK: - Property
    // The filtered destination's bitmap holds at most this many times the context's pixels, past its own size.
    private static let pixelLimit = 2.0

    private let tables: LookUpTableCache

    // MARK: - Initializer
    init(tables: LookUpTableCache) {
        self.tables = tables
    }

    // MARK: - Public
    // A nil source is a nested list none of which lands in the frame, so only the border is drawn.
    func draw(
        _ item: PictureItem,
        source: SourceImage?,
        matte: CGImage?,
        seed: Int,
        in context: CGContext
    ) throws {
        let destination = CGRect(item.destination)
        guard destination.width > 0, destination.height > 0 else { return }

        var placement = CGAffineTransform.identity
        if let source {
            guard let placed = item.placement(ofSourceSized: source.size) else { return }

            placement = placed
        }
        guard !item.filter.isEmpty || item.matte != nil else {
            framed(item, in: context) { context in
                guard let source else { return }

                context.concatenate(placement)
                source.draw(in: context)
            }

            return
        }

        let scale = scale(of: destination, in: context)
        guard scale > 0 else { return }

        let size = Size(width: destination.width * scale, height: destination.height * scale)
        let local = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: -destination.minX, y: -destination.minY)
        let scaled = try FrameContext(holding: size)
        scaled.context.concatenate(local)
        scaled.context.clip(to: destination)
        if let source {
            scaled.context.concatenate(placement)
            source.draw(in: scaled.context)
        }

        var picture = try scaled.ciImage()
        let extent = picture.extent
        picture = try FilterChain(tables: tables)
            .apply(item.filter, to: picture, seed: seed, scale: scale)
            .cropped(to: extent)
        if let pictureMatte = item.matte, let matte {
            picture = try MatteApplier().apply(pictureMatte, frame: matte, to: picture, size: size)
        }

        let filtered = try FrameContext.cgImage(of: picture, in: extent)
        let bounds = CGRect(
            x: destination.minX,
            y: destination.minY,
            width: extent.width / scale,
            height: extent.height / scale
        )
        let finished = try FrameContext(holding: size)
        finished.context.concatenate(local)
        framed(item, in: finished.context) { context in
            context.drawUpright(filtered, in: bounds)
        }
        context.drawUpright(try finished.image(), in: bounds)
    }

    // MARK: - Private
    // Pixels per unit of the item's coordinates in the filtered bitmap: the larger axis scale the context shows them
    // at, so no direction is drawn coarser than the output, held to the pixel limit when that is larger than the
    // destination at its own size.
    private func scale(
        of destination: CGRect,
        in context: CGContext
    ) -> CGFloat {
        let shown = context.ctm.axisScale
        let limit = (Self.pixelLimit * CGFloat(context.width * context.height) / (destination.width * destination.height))
            .squareRoot()

        return min(max(shown.width, shown.height), max(1, limit))
    }

    // What `drawing` draws cut to the destination with its corners rounded, and the border over it.
    private func framed(
        _ item: PictureItem,
        in context: CGContext,
        drawing: (CGContext) -> Void
    ) {
        let destination = item.destination
        context.saveGState()
        context.addPath(PathOutline(.rect(destination, radius: item.radius)).path)
        context.clip()
        drawing(context)
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
