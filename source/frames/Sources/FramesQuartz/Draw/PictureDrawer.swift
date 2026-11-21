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
// filtered at the scale the context shows its destination at, its filter's lengths scaled with it, so it is as sharp
// as the source it is drawn from. A page of a PDF is filtered at that scale over the part of its destination that
// reaches the context, grown by how far its filter reads, on the pixel grid of the whole destination, so its filter's
// grids and its matte lie where they lie on the whole (FRAMES-20 Pictures). Any other picture is filtered over its
// whole destination, at a scale held to the pixel limit. `transform` carries the item's coordinates to output pixels,
// which the border's width is in. Its bitmaps are in the form `compositing` names, its list's, so the picture is
// resampled, filtered and cut in that form.
struct PictureDrawer {
    // MARK: - Property
    // The filtered destination's bitmap of a picture other than a page holds at most this many times the context's
    // pixels, past its own size.
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

        let isPage = if case let .media(frame) = item.source { frame.picture == .page } else { false }
        let scale = isPage ? shownScale(in: context) : scale(of: destination, in: context)
        guard scale > 0 else { return }

        // The whole destination's pixels and the part of them drawn, y pointing down from its top left.
        let size = CGSize(width: destination.width * scale, height: destination.height * scale)
        let whole = CGRect(x: 0, y: 0, width: size.width.rounded(.up), height: size.height.rounded(.up))
        let part = isPage ? shownPart(of: item, at: scale, within: whole, in: context) : whole
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

        // Core Image counts rows from the bottom, so the part lies at its place in the whole destination's image.
        var picture = try scaled.ciImage()
            .transformed(by: CGAffineTransform(translationX: part.minX, y: whole.height - part.maxY))
        let extent = picture.extent
        picture = try FilterChain(tables: tables)
            .apply(item.filter, to: picture, seed: seed, scale: scale, frame: whole, compositing: compositing)
            .cropped(to: extent)
        if let pictureMatte = item.matte, let matte {
            let shown = CGRect(x: 0, y: whole.height - size.height, width: size.width, height: size.height)
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
    // Pixels per unit of the item's coordinates in the filtered bitmap of a picture other than a page: the shown
    // scale, held to the pixel limit when that is larger than the destination at its own size.
    private func scale(
        of destination: CGRect,
        in context: CGContext
    ) -> CGFloat {
        let limit = (Self.pixelLimit * CGFloat(context.width * context.height) / (destination.width * destination.height))
            .squareRoot()

        return min(shownScale(in: context), max(1, limit))
    }

    // The larger axis scale the context shows the item's coordinates at, so no direction is drawn coarser than the
    // output.
    private func shownScale(in context: CGContext) -> CGFloat {
        let shown = context.ctm.axisScale

        return max(shown.width, shown.height)
    }

    // The pixels of `whole`, the destination at `scale`, that the context's clip reaches or the filter reads from
    // there, each side moved out to a whole pixel. It is empty where none of the destination reaches the context.
    private func shownPart(
        of item: PictureItem,
        at scale: CGFloat,
        within whole: CGRect,
        in context: CGContext
    ) -> CGRect {
        let destination = CGRect(item.destination)
        let reach = CGFloat(FilterChain(tables: tables).reach(of: item.filter))
        let shown = context.boundingBoxOfClipPath.insetBy(dx: -reach, dy: -reach).intersection(destination)
        guard !shown.isNull, !shown.isEmpty else { return .null }

        let left = ((shown.minX - destination.minX) * scale).rounded(.down)
        let top = ((shown.minY - destination.minY) * scale).rounded(.down)
        let right = ((shown.maxX - destination.minX) * scale).rounded(.up)
        let bottom = ((shown.maxY - destination.minY) * scale).rounded(.up)

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
