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
// masked by its matte, its corners rounded, and its border over it along the destination's edge. Every source is
// resampled onto the context's pixels by `PictureResampler` (FRAMES-21 Rules) and drawn there on whole pixels, covered
// once at each edge: by the resampler where the destination's corners are square, and by a clip to the destination
// with its corners rounded where they are not, the source then extended past the destination. A picture with no
// filter or matte is resampled from its source straight onto the output. A filtered
// picture is filtered at the scale the context shows its destination at, held to the pixel limit, its filter's
// lengths scaled with it, so it is as sharp as the source it is drawn from. It is filtered over the part of its
// destination that reaches the context, grown by how far its filter reads, on the pixel grid of the whole
// destination, so its filter's grids and its matte lie where they lie on the whole (FRAMES-20 Pictures). `transform`
// carries the item's coordinates to output pixels, which the border's width is in. Its bitmaps are in the form
// `compositing` names, its list's, so the picture is resampled, filtered and cut in that form.
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
            if let source {
                if item.radius == 0 {
                    if let shown = item.shownSource(ofSourceSized: source.size) {
                        try resampled(source, placedBy: placement, covering: shown, compositing: compositing, in: context)
                    }
                } else {
                    let extended = item.extendedSource(ofSourceSized: source.size)
                    try framed(item, in: context) { context in
                        try resampled(source, placedBy: placement, covering: extended, compositing: compositing, in: context)
                    }
                }
            }
            border(of: item, carriedBy: transform, in: context)

            return
        }

        let reach = CGFloat(chain.reach(of: item.filter))
        let region = context.boundingBoxOfClipPath.insetBy(dx: -reach, dy: -reach).intersection(destination)
        guard !region.isNull, !region.isEmpty else { return border(of: item, carriedBy: transform, in: context) }

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
        // The source reaches past the destination, as a filter reads past its edge, and is cut to it after the filter.
        if let source {
            try resampled(
                source,
                placedBy: placement,
                covering: item.extendedSource(ofSourceSized: source.size),
                compositing: compositing,
                in: scaled.context
            )
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
        try framed(item, in: finished.context) { context in
            context.drawUpright(filtered, in: bounds)
        }
        // The finished part's pixels, in units of the item's coordinates from the part's top left, covered by their own
        // bounds, whose alpha already holds the destination's edge.
        let finishedPart = SourceImage(try finished.image(), of: bounds.size, transform: CGAffineTransform(scaleX: scale, y: scale))
        try resampled(
            finishedPart,
            placedBy: CGAffineTransform(translationX: bounds.minX, y: bounds.minY),
            covering: CGRect(origin: .zero, size: bounds.size),
            compositing: compositing,
            in: context
        )
        border(of: item, carriedBy: transform, in: context)
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

    // What `drawing` draws cut to the destination with its corners rounded. `drawing` may move the context to place
    // its source.
    private func framed(
        _ item: PictureItem,
        in context: CGContext,
        drawing: (CGContext) throws -> Void
    ) throws {
        context.saveGState()
        defer { context.restoreGState() }

        context.addPath(PathOutline(.rect(item.destination, radius: item.radius)).path)
        context.clip()
        try drawing(context)
    }

    // Draws `source`, carried into the item's coordinates by `placement`, resampled onto the context's pixels and
    // covered by `cover`, a rectangle of the source's coordinates, over the part of the context its clip leaves. A
    // source moved by whole pixels at its own size, cut on whole pixels inside it, is its own pixels, which Core
    // Graphics copies as they are.
    private func resampled(
        _ source: SourceImage,
        placedBy placement: CGAffineTransform,
        covering cover: CGRect,
        compositing: Compositing,
        in context: CGContext
    ) throws {
        // Core Image counts the source's rows from the bottom, as the context's device space counts its own.
        let device = context.ctm
        let imageBounds = CGRect(x: 0, y: 0, width: source.image.width, height: source.image.height)
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: imageBounds.height)
        let map = flip.concatenating(source.transform.inverted()).concatenating(placement).concatenating(device)
        let covered = cover.applying(source.transform).applying(flip)
        let area = context.boundingBoxOfClipPath
            .applying(device)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        guard !area.isNull, !area.isEmpty else { return }

        let resampler = PictureResampler()
        context.saveGState()
        defer { context.restoreGState() }

        if let landed = resampler.wholePixels(of: map, covering: covered, within: area),
           imageBounds.applying(map).contains(landed) {
            context.concatenate(device.inverted())
            context.clip(to: landed)
            context.interpolationQuality = .none
            context.draw(source.image, in: imageBounds.applying(map))

            return
        }

        let image = try resampler.resample(CIImage(cgImage: source.image), through: map, covering: covered, within: area)
        guard !image.extent.isEmpty else { return }

        let drawn = try FrameContext.cgImage(of: image, in: image.extent, compositing: compositing)
        context.concatenate(device.inverted())
        context.interpolationQuality = .none
        context.draw(drawn, in: image.extent)
    }

    // The border along the carried outline of the destination with its corners rounded, a stroke with miter joins on
    // the side of it the border's `align` names, so its edges follow the rounded corners and it is as wide on every
    // side in output pixels. It is drawn over the picture, outside the destination where it lies there.
    private func border(
        of item: PictureItem,
        carriedBy transform: Frames.AffineTransform,
        in context: CGContext
    ) {
        guard let border = item.border, border.width > 0, let back = transform.inverse else { return }

        let outline = PathOutline(.rect(item.destination, radius: item.radius)).carried(by: transform)
        let band = outline.path.copy(
            strokingWithWidth: CGFloat(border.align.tracedWidth(of: border.width)),
            lineCap: .butt,
            lineJoin: .miter,
            miterLimit: CGFloat(StrokeJoin.miterLimit)
        )
        var matrix = CGAffineTransform(back)
        guard let placed = band.cut(to: border.align, of: outline)?.copy(using: &matrix) else { return }

        context.addPath(placed)
        context.setFillColor(border.color.cgColor)
        context.fillPath(using: .winding)
    }
}
