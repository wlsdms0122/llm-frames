//
//  PictureDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Frames

// Draws a picture item in its item's own coordinates: the source region scaled into the destination, filtered,
// masked by its matte, its corners rounded and its border inside the destination's edge. A picture with no filter or
// matte is drawn straight from its source, so it is resampled once on its way to the output. A filtered picture is
// filtered at the scale the context shows its destination at, held to the pixel limit, its filter's lengths scaled
// with it, so it is as sharp as the source it is drawn from. It is filtered over the part of its destination that
// reaches the context, grown by how far its filter reads, on the pixel grid of the whole destination, so its filter's
// grids and its matte lie where they lie on the whole (FRAMES-20 Pictures). `transform` carries the item's
// coordinates to output pixels, which the border's width is in. Its bitmaps are in the form `compositing` names, its
// list's, so the picture is resampled, filtered and cut in that form.
struct PictureDrawer {
    // MARK: - Property
    private let chain: FilterChain

    // MARK: - Initializer
    init(chain: FilterChain) {
        self.chain = chain
    }

    // MARK: - Public
    // A nil source is a nested list none of which lands in the frame, so only the border is drawn.
    func draw(
        _ item: PictureItem,
        source: SourceImage?,
        matte: SourceImage?,
        seed: Int,
        carriedBy transform: Frames.AffineTransform,
        compositing: Compositing,
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
            framed(item, carriedBy: transform, in: context) { context in
                guard let source else { return }

                context.concatenate(placement)
                source.draw(in: context)
            }

            return
        }

        let reach = CGFloat(chain.reach(of: item.filter))
        let region = context.boundingBoxOfClipPath.insetBy(dx: -reach, dy: -reach).intersection(destination)
        guard !region.isNull, !region.isEmpty else { return }

        let scale = scale(of: region, reaching: reach, in: context)
        guard scale > 0 else { return }

        // The whole destination's pixels and the part of them drawn, y pointing down from its top left.
        let size = CGSize(width: destination.width * scale, height: destination.height * scale)
        let whole = CGRect(x: 0, y: 0, width: size.width.rounded(.up), height: size.height.rounded(.up))
        let part = pixels(of: region, in: destination, at: scale, within: whole)
        guard !part.isEmpty else { return }

        let partSize = Size(width: part.width, height: part.height)
        let local = CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: -destination.minX, y: -destination.minY)
            .concatenating(CGAffineTransform(translationX: -part.minX, y: -part.minY))
        let scaled = try FrameContext(holding: partSize, compositing: compositing)
        scaled.context.concatenate(local)
        scaled.context.clip(to: destination)
        if let source {
            scaled.context.concatenate(placement)
            source.draw(in: scaled.context)
        }

        // Core Image counts rows from the bottom, so the part lies at its place in the whole destination's image, and
        // the destination at `shown`.
        var picture = try scaled.ciImage()
            .transformed(by: CGAffineTransform(translationX: part.minX, y: whole.height - part.maxY))
        let extent = picture.extent
        let shown = CGRect(x: 0, y: whole.height - size.height, width: size.width, height: size.height)
        picture = try chain
            .apply(item.filter, to: picture, seed: seed, scale: scale, frame: shown, compositing: compositing)
            .cropped(to: extent)
        if let pictureMatte = item.matte, let matte {
            picture = try MatteApplier()
                .apply(pictureMatte, frame: matte, to: picture, over: shown)
        }

        let filtered = try FrameContext.cgImage(of: picture, in: extent, compositing: compositing)
        let bounds = CGRect(
            x: destination.minX + part.minX / scale,
            y: destination.minY + part.minY / scale,
            width: part.width / scale,
            height: part.height / scale
        )
        let finished = try FrameContext(holding: partSize, compositing: compositing)
        finished.context.concatenate(local)
        framed(item, carriedBy: transform, in: finished.context) { context in
            context.drawUpright(filtered, in: bounds)
        }
        context.drawUpright(try finished.image(), in: bounds)
    }

    // MARK: - Private
    // Pixels per unit of the item's coordinates in the filtered bitmap of `region`, the part of the destination drawn:
    // the shown scale, held to the pixel limit against the context grown by `reach`, how far the filter reads.
    private func scale(
        of region: CGRect,
        reaching reach: CGFloat,
        in context: CGContext
    ) -> CGFloat {
        let shown = shownScale(in: context)
        let margin = 2 * reach * shown
        let area = CGSize(width: CGFloat(context.width) + margin, height: CGFloat(context.height) + margin)

        return PixelLimit().scale(CGSize(width: shown, height: shown), covering: region.size, within: area).width
    }

    // The larger axis scale the context shows the item's coordinates at, so no direction is drawn coarser than the
    // output.
    private func shownScale(in context: CGContext) -> CGFloat {
        let shown = context.ctm.axisScale

        return max(shown.width, shown.height)
    }

    // The pixels of `whole`, the destination at `scale`, that `region` covers, each side moved out to a whole pixel.
    private func pixels(
        of region: CGRect,
        in destination: CGRect,
        at scale: CGFloat,
        within whole: CGRect
    ) -> CGRect {
        let left = ((region.minX - destination.minX) * scale).rounded(.down)
        let top = ((region.minY - destination.minY) * scale).rounded(.down)
        let right = ((region.maxX - destination.minX) * scale).rounded(.up)
        let bottom = ((region.maxY - destination.minY) * scale).rounded(.up)

        return CGRect(x: left, y: top, width: right - left, height: bottom - top).intersection(whole)
    }

    // What `drawing` draws cut to the destination with its corners rounded, and the border over it.
    private func framed(
        _ item: PictureItem,
        carriedBy transform: Frames.AffineTransform,
        in context: CGContext,
        drawing: (CGContext) -> Void
    ) {
        let outline = PathOutline(.rect(item.destination, radius: item.radius))
        context.saveGState()
        context.addPath(outline.path)
        context.clip()
        drawing(context)

        // The border is the inside half of a stroke twice its width along the carried outline, so its outer edge
        // follows the rounded corners and it is as wide on every side in output pixels.
        if let border = item.border, border.width > 0, let back = transform.inverse {
            var matrix = CGAffineTransform(back)
            let band = outline.carried(by: transform).path.copy(
                strokingWithWidth: CGFloat(2 * border.width),
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: CGFloat(StrokeJoin.miterLimit)
            )
            if let placed = band.copy(using: &matrix) {
                context.addPath(placed)
                context.setFillColor(border.color.cgColor)
                context.fillPath(using: .winding)
            }
        }
        context.restoreGState()
    }
}
