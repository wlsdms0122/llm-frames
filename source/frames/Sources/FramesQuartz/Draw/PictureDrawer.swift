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
// filter or matte is resampled from its source straight onto the output. A filtered picture is one Core Image image
// from its source to the output's pixels (`filtered`), which `quartz` renders and draws and `metal` composites as it
// is. It is filtered at the scale the context shows its destination at, held to the pixel limit, its filter's
// lengths scaled with it, so it is as sharp as the source it is drawn from. It is filtered over the part of its
// destination that reaches the context, grown by how far its filter reads, on the pixel grid of the whole
// destination, so its filter's grids and its matte lie where they lie on the whole (FRAMES-20 Pictures), and cut
// there by the coverage Core Graphics gives the destination with its corners rounded. `transform` carries the item's
// coordinates to output pixels, which the border's width is in. The picture is resampled, filtered and cut in the
// form `compositing` names, its list's.
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
            Self.border(of: item, carriedBy: transform, in: context)

            return
        }

        let device = context.ctm
        let area = context.boundingBoxOfClipPath
            .applying(device)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        if !area.isNull, !area.isEmpty {
            let image = try filtered(
                item,
                source: source,
                matte: matte,
                seed: seed,
                through: device,
                within: area,
                compositing: compositing
            )
            try draw(image, through: device, compositing: compositing, in: context)
        }
        Self.border(of: item, carriedBy: transform, in: context)
    }

    // The filtered picture as one Core Image image of the output's pixels, rows counted from the bottom, within
    // `area`, whole pixels of the output: its source resampled onto the resolution it is filtered at, filtered, masked
    // by its matte, cut by its destination with its corners rounded, whose coverage Core Graphics gives at that
    // resolution, and resampled onto the output. `device` carries the item's coordinates to the output's pixels. The
    // image is left unrendered, so a renderer computes it in the form `compositing` names when it draws or composites
    // it. Its border is not in it. A nil source is a nested list none of which lands in the frame, so the filter takes
    // transparent pixels.
    func filtered(
        _ item: PictureItem,
        source: SourceImage?,
        matte: SourceImage?,
        seed: Int,
        through device: CGAffineTransform,
        within area: CGRect,
        compositing: Compositing
    ) throws -> CIImage {
        let destination = CGRect(item.destination)
        guard destination.width > 0, destination.height > 0 else { return .empty() }

        var placement = CGAffineTransform.identity
        if let source {
            guard let placed = item.placement(ofSourceSized: source.size) else { return .empty() }

            placement = placed
        }

        let reach = CGFloat(chain.reach(of: item.filter))
        let region = area.applying(device.inverted()).insetBy(dx: -reach, dy: -reach).intersection(destination)
        guard !region.isNull, !region.isEmpty else { return .empty() }

        let scale = scale(of: region, reaching: reach, through: device, within: area.size)
        guard scale > 0 else { return .empty() }

        // The whole destination's pixels and the part of them drawn, y pointing down from its top left.
        let size = CGSize(width: destination.width * scale, height: destination.height * scale)
        let whole = CGRect(x: 0, y: 0, width: size.width.rounded(.up), height: size.height.rounded(.up))
        let part = pixels(of: region, in: destination, at: scale, within: whole)
        guard !part.isEmpty else { return .empty() }

        let partBounds = CGRect(origin: .zero, size: part.size)
        let local = CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: -destination.minX, y: -destination.minY)
            .concatenating(CGAffineTransform(translationX: -part.minX, y: -part.minY))
        // The part's pixels, rows counted from the bottom.
        let partDevice = local.concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: part.height))
        var picture = CIImage(color: .clear).cropped(to: partBounds)
        // The source reaches past the destination, as a filter reads past its edge, and is cut to it after the filter.
        if let source {
            picture = try resampled(
                source,
                placedBy: placement,
                covering: item.extendedSource(ofSourceSized: source.size),
                through: partDevice,
                within: partBounds
            )
            .composited(over: picture)
        }

        // Core Image counts rows from the bottom, so the part lies at its place in the whole destination's image, and
        // the destination at `shown`.
        let place = CGAffineTransform(translationX: part.minX, y: whole.height - part.maxY)
        picture = picture.transformed(by: place)
        let extent = picture.extent
        let shown = CGRect(x: 0, y: whole.height - size.height, width: size.width, height: size.height)
        picture = try chain
            .apply(item.filter, to: picture, seed: seed, scale: scale, frame: shown, compositing: compositing)
            .cropped(to: extent)
        if let pictureMatte = item.matte, let matte {
            picture = try MatteApplier()
                .apply(pictureMatte, frame: matte, to: picture, over: shown)
        }

        let coverage = try FrameContext(holding: Size(width: part.width, height: part.height), compositing: compositing)
        coverage.context.concatenate(local)
        coverage.context.addPath(PathOutline(.rect(item.destination, radius: item.radius)).path)
        coverage.context.setFillColor(CGColor(gray: 1, alpha: 1))
        coverage.context.fillPath()
        let cut = picture
            .transformed(by: place.inverted())
            .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: try coverage.ciImage()])
        // The cut part's pixels, in units of the item's coordinates from the part's top left, covered by their own
        // bounds, whose alpha already holds the destination's edge.
        let bounds = CGRect(
            x: destination.minX + part.minX / scale,
            y: destination.minY + part.minY / scale,
            width: part.width / scale,
            height: part.height / scale
        )
        let map = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: part.height)
            .concatenating(CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
            .concatenating(CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
            .concatenating(device)

        return try PictureResampler().resample(cut, through: map, covering: partBounds, within: area)
    }

    // The border along the carried outline of the destination with its corners rounded, a stroke with miter joins on
    // the side of it the border's `align` names, so its edges follow the rounded corners and it is as wide on every
    // side in output pixels. It is drawn over the picture, outside the destination where it lies there.
    static func border(
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

    // MARK: - Private
    // Pixels per unit of the item's coordinates in the filtered bitmap of `region`, the part of the destination drawn:
    // the larger axis scale `device` shows the item's coordinates at, so no direction is drawn coarser than the
    // output, held to the pixel limit against `drawn`, the output's pixels drawn, grown by `reach`, how far the filter
    // reads.
    private func scale(
        of region: CGRect,
        reaching reach: CGFloat,
        through device: CGAffineTransform,
        within drawn: CGSize
    ) -> CGFloat {
        let axes = device.axisScale
        let shown = max(axes.width, axes.height)
        let margin = 2 * reach * shown
        let area = CGSize(width: drawn.width + margin, height: drawn.height + margin)

        return PixelLimit().scale(CGSize(width: shown, height: shown), covering: region.size, within: area).width
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

        // A surface the decoder gave is read on the GPU where it lies.
        let image = try resampler.resample(source.picture, through: map, covering: covered, within: area)
        try draw(image, through: device, compositing: compositing, in: context)
    }

    // `source`, carried into the item's coordinates by `placement`, resampled through `device` onto the pixels of an
    // output whose rows are counted from the bottom, covered by `cover`, a rectangle of the source's coordinates, within
    // `area` of those pixels.
    private func resampled(
        _ source: SourceImage,
        placedBy placement: CGAffineTransform,
        covering cover: CGRect,
        through device: CGAffineTransform,
        within area: CGRect
    ) throws -> CIImage {
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: source.picture.extent.height)
        let map = flip.concatenating(source.transform.inverted()).concatenating(placement).concatenating(device)
        let covered = cover.applying(source.transform).applying(flip)

        return try PictureResampler().resample(source.picture, through: map, covering: covered, within: area)
    }

    // Draws `image`, of the context's device pixels, on whole pixels as it is, computed in the form `compositing`
    // names.
    private func draw(
        _ image: CIImage,
        through device: CGAffineTransform,
        compositing: Compositing,
        in context: CGContext
    ) throws {
        guard !image.extent.isEmpty else { return }

        let drawn = try FrameContext.cgImage(of: image, in: image.extent, compositing: compositing)
        context.saveGState()
        defer { context.restoreGState() }

        context.concatenate(device.inverted())
        context.interpolationQuality = .none
        context.draw(drawn, in: image.extent)
    }
}
